patchesSrc=$1
shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

tryApply() {
  rm -rf "$work/try"
  cp -r "$1" "$work/try"
  patch -d "$work/try" -p1 -f --silent ${3:+"$3"} <"$2" >/dev/null 2>&1
}

channels=()
for arg in "$@"; do
  channel=${arg%%=*}
  channels+=("$channel")
  cp -r --no-preserve=mode "${arg#*=}" "$work/$channel"
  sed -nE 's/^_VERSION[[:space:]]*=[[:space:]]*//p' "$work/$channel/config.mk" |
    sed 's/-dev$//' >"$work/$channel.version"
done

for dir in "$patchesSrc"/patches/*/; do
  name=$(basename "$dir")
  readme="$work/README.md"
  tr -d '\r' <"$dir/README.md" >"$readme" 2>/dev/null || : >"$readme"

  description=$(awk '
    /^###/ { if (found) exit; if ($0 ~ /^### *Description/) { found = 1; next } }
    found && NF == 0 && started { exit }
    found && NF > 0 { started = 1; print }
  ' "$readme")

  requires=$(rg -o "/(patches|wiki)/[A-Za-z0-9_.-]+" "$readme" | cut -d/ -f3 | rg -vxF "$name" | while read -r dep; do
    [ -d "$patchesSrc/patches/$dep" ] && echo "$dep"
  done | head -n1 || true)

  for channel in "${channels[@]}"; do
    rm -rf "$work/$channel-base"
    if [ -n "$requires" ]; then
      for dep in "$patchesSrc/patches/$requires"/*.patch; do
        rm -rf "$work/$channel-base"
        cp -r "$work/$channel" "$work/$channel-base"
        patch -d "$work/$channel-base" -p1 -f --silent <"$dep" >/dev/null 2>&1 && break
        rm -rf "$work/$channel-base"
      done
    fi
  done

  for f in "$dir"*.patch; do
    [ -e "$f" ] || continue
    file=$(basename "$f")

    applies='{}'
    needs='{}'
    fuzzy='{}'
    for channel in "${channels[@]}"; do
      ok=false
      base="$work/$channel"
      if tryApply "$base" "$f"; then
        ok=true
      elif [ -d "$work/$channel-base" ] && tryApply "$work/$channel-base" "$f"; then
        ok=true
        base="$work/$channel-base"
        needs=$(jq -c --arg c "$channel" '. + {($c): true}' <<<"$needs")
      fi
      if $ok && ! tryApply "$base" "$f" -F0; then
        fuzzy=$(jq -c --arg c "$channel" '. + {($c): true}' <<<"$fuzzy")
      fi
      applies=$(jq -c --arg c "$channel" --argjson ok "$ok" '. + {($c): $ok}' <<<"$applies")
    done

    pkgConfig=$(awk '
      /^\+PKGS[ \t]*=/ {
        sub(/^\+PKGS[ \t]*=/, "")
        for (i = 1; i <= NF; i++)
          if ($i !~ /^(wayland-server|xkbcommon|libinput|wlroots)/ && substr($i, 1, 1) != "$") print $i
      }
      /^\+#include <(libdrm\/|drm_fourcc\.h)/ { print "libdrm" }
      /^\+#include <(pixman\.h|pixman-1\/)/ { print "pixman-1" }
      /^\+#include <fcft\// { print "fcft" }
      /^\+#include <dbus\// { print "dbus-1" }
      /^\+#include <libevdev\// { print "libevdev" }
      /^\+#include <libudev\.h>/ { print "libudev" }
      ' "$f" | sort -u | jq -R . | jq -sc .)

    target=$(rg -o "\[[^\]]+\]\([^)]*/$file\)" "$readme" | head -n1 |
      sed -E 's/^\[([^]]+)\].*/\1/' || true)

    jq -nc --arg file "$file" --arg target "$target" \
      --argjson applies "$applies" --argjson needs "$needs" --argjson fuzzy "$fuzzy" --argjson pkgConfig "$pkgConfig" \
      '{file: $file, applies: $applies, needsRequired: $needs, fuzzy: $fuzzy, pkgConfig: $pkgConfig,
        target: (if $target == "" then null else $target end)}'
  done >"$work/files.jsonl"

  versions=$(for channel in "${channels[@]}"; do
    jq -nc --arg c "$channel" --arg v "$(cat "$work/$channel.version")" '{($c): $v}'
  done | jq -sc add)

  jq -sc --arg name "$name" --arg description "$description" --arg requires "$requires" --argjson versions "$versions" '
    . as $files
    | def pick($channel):
        ($files | map(select(.applies[$channel])) | sort_by(.fuzzy[$channel] // false) | map(.file)) as $ok
        | ([$ok[] | select(($channel != "main") and contains($versions[$channel]))]
           + [$ok[] | select(. == "\($name).patch")]
           + [$ok[] | select(contains("main"))]
           + $ok)[0];
    {
      key: $name,
      value: {
        description: (if $description == "" then null else $description end),
        requires: (if $requires == "" or ($files | all(.needsRequired == {})) then null else $requires end),
        default: ($versions | keys | map({key: ., value: pick(.)}) | from_entries),
        files: ($files | map({key: .file, value: del(.file)}) | from_entries)
      }
    }' "$work/files.jsonl"
done | jq -S -s 'from_entries'
