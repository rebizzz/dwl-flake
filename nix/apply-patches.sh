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
  filterdiff -p1 -i config.def.h "$p" | patch -p1 -f -s -r "$rej" config.def.h >/dev/null 2>&1 || true

  added=$(awk '
    /^\+#define[ \t]/ {
      line = substr($0, 2)
      split(line, parts, /[ \t(]+/)
      print parts[2] "\t" line
      next
    }
    /^\+static / {
      line = substr($0, 2)
      name = line
      sub(/[ \t]*(\[[^]]*\])?[ \t]*=.*$/, "", name)
      n = split(name, parts, /[ \t*]+/)
      print parts[n] "\t" line
      next
    }
  ' "$rej")

  merged=""
  while IFS=$'\t' read -r name line; do
    [ -n "$name" ] || continue
    rg -q "\\b$name\\b" config.def.h && continue
    merged="$merged$line"$'\n'
  done <<<"$added"

  if [ -n "$merged" ]; then
    awk -v block="$merged" '
      !done && /^static const Rule rules\[\]/ { printf "%s", block; done = 1 }
      { print }
      END { if (!done) printf "%s", block }
    ' config.def.h >config.def.h.new
    mv config.def.h.new config.def.h
  fi

  echo "note: $p conflicted in config.def.h, merged its declarations:"
  printf '%s' "$merged" | sed 's/^/  /'
  if rg -q '^\+[^+]' "$rej" && rg -v '^\+(static |#define )' "$rej" | rg -q '^\+[^+]'; then
    echo "note: lines from $p that aren't declarations were left out (e.g. keybinds), add them yourself if needed:"
    rg '^\+[^+]' "$rej" | rg -v '^\+(static |#define )' | sed 's/^+/  /'
  fi
  rm -f "$rest" "$rej"
done

runHook postPatch
