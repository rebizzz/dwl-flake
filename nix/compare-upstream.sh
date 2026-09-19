lock=flake.lock
rev() { jq -r ".nodes[\"$1\"].locked.rev" "$lock"; }
system=$(nix eval --impure --raw --expr builtins.currentSystem)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "cloning dwl and dwl-patches from codeberg"
git clone -q https://codeberg.org/dwl/dwl.git "$work/dwl"
git clone -q https://codeberg.org/dwl/dwl-patches.git "$work/dwl-patches"
git -C "$work/dwl-patches" checkout -q "$(rev dwl-patches-src)"

echo "building the flake's patched sources"
flake=$(nix build --no-link --print-out-paths ".#legacyPackages.$system.patchedSourcesAll")

nix eval --json .#lib.upstreamPlan >"$work/plan.json"

failed=0
total=0
for channel in main stable; do
  if [ "$channel" = main ]; then base=$(rev dwl-src); else base=$(rev dwl-stable-src); fi

  while read -r entry; do
    name=$(jq -r .name <<<"$entry")
    total=$((total + 1))
    tree="$work/tree"
    rm -rf "$tree"
    git -C "$work/dwl" worktree add -q -f --detach "$tree" "$base"

    ok=true
    for p in $(jq -r '[.requires, {name, file}] | map(select(.)) | .[] | "\(.name)/\(.file)"' <<<"$entry"); do
      patch -d "$tree" -p1 -f -s <"$work/dwl-patches/patches/$p" >/dev/null 2>&1 || ok=false
    done

    if ! $ok; then
      echo "FAIL $channel $name: doesn't apply by hand"
      failed=$((failed + 1))
    elif ! diff -r -q -x .git "$tree" "$flake/$channel/$name" >/dev/null; then
      echo "FAIL $channel $name: flake result differs from patching by hand"
      diff -r -u -x .git "$tree" "$flake/$channel/$name" | head -40 || true
      failed=$((failed + 1))
    fi

    git -C "$work/dwl" worktree remove -f "$tree"
  done < <(jq -c --arg c "$channel" '.[$c][]' "$work/plan.json")
done

echo "$((total - failed))/$total patches identical to patching codeberg's dwl by hand"
[ "$failed" -eq 0 ]
