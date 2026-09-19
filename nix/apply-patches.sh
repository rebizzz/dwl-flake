runHook prePatch

for p in "${patches[@]}"; do
  echo "applying $p"
  if patch -p1 -f --dry-run -s <"$p" >/dev/null 2>&1; then
    patch -p1 -f -s <"$p"
    continue
  fi

  rest=$(mktemp)
  filterdiff -p1 -x config.def.h "$p" >"$rest"
  if [ -s "$rest" ] && ! patch -p1 -f --dry-run -s <"$rest" >/dev/null 2>&1; then
    echo "error: $p conflicts outside config.def.h" >&2
    patch -p1 -f --dry-run <"$rest" >&2 || true
    exit 1
  fi
  [ -s "$rest" ] && patch -p1 -f -s <"$rest"

  rej=$(mktemp)
  filterdiff -p1 -i config.def.h "$p" | patch -p1 -f -s -F0 -r "$rej" config.def.h >/dev/null 2>&1 || true

  decls=$(mktemp -d)
  awk -v dir="$decls" '
    function flush() { if (name != "") { print block > (dir "/" name); close(dir "/" name) } name = ""; block = "" }
    collecting && /^\+/ {
      block = block "\n" substr($0, 2)
      if ($0 ~ /^\+[ \t]*\};/) { collecting = 0; flush() }
      next
    }
    /^\+#define[ \t]/ {
      line = substr($0, 2)
      split(line, parts, /[ \t(]+/)
      name = parts[2]; block = line; flush(); next
    }
    /^\+static / {
      line = substr($0, 2)
      decl = line
      sub(/[ \t]*(\[[^]]*\])?[ \t]*=.*$/, "", decl)
      n = split(decl, parts, /[ \t*]+/)
      name = parts[n]; block = line
      if (line ~ /\{[^}]*$/) collecting = 1; else flush()
      next
    }
    /^\+\+\+/ { next }
    /^\+/ { print substr($0, 2) > (dir "/.dropped") }
  ' "$rej"

  merged=""
  for f in "$decls"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    rg -q "\\b$name\\b" config.def.h && continue
    merged="$merged$(cat "$f")"$'\n'
  done

  if [ -n "$merged" ]; then
    printf '\n%s' "$merged" >>config.def.h
  fi

  echo "note: $p conflicted in config.def.h, merged its declarations:"
  printf '%s' "$merged" | sed 's/^/  /'
  if [ -s "$decls/.dropped" ]; then
    echo "note: lines from $p that aren't declarations were left out (e.g. keybinds), add them yourself if needed:"
    sed 's/^/  /' "$decls/.dropped"
  fi
  rm -rf "$rest" "$rej" "$decls"
done

runHook postPatch
