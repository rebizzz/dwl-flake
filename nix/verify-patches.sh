system=$(nix eval --impure --raw --expr builtins.currentSystem)
plan=$(nix eval --json .#lib.verifyPlan)
results='{"main": {}, "stable": {}}'
pending=$(jq -c '[.[] | {channel, name, candidates, round: 0}]' <<<"$plan")

while [ "$(jq length <<<"$pending")" -gt 0 ]; do
  targets=$(jq -r --arg s "$system" '.[] | ".#legacyPackages.\($s).variantTests.\(.channel).\"\(.name)\".\"\(.candidates[.round])\""' <<<"$pending")
  echo "building $(jq length <<<"$pending") variants"

  mapfile -t installables <<<"$targets"
  nix build --keep-going --no-link "${installables[@]}" 2>/dev/null || true

  next='[]'
  while read -r entry; do
    channel=$(jq -r .channel <<<"$entry")
    name=$(jq -r .name <<<"$entry")
    round=$(jq -r .round <<<"$entry")
    file=$(jq -r '.candidates[.round]' <<<"$entry")

    if nix path-info ".#legacyPackages.$system.variantTests.$channel.\"$name\".\"$file\"" >/dev/null 2>&1; then
      if [ "$round" -gt 0 ]; then
        echo "  $channel $name: using $file"
        results=$(jq -c --arg c "$channel" --arg n "$name" --arg f "$file" '.[$c][$n] = $f' <<<"$results")
      fi
    elif [ "$((round + 1))" -lt "$(jq '.candidates | length' <<<"$entry")" ]; then
      next=$(jq -c --argjson e "$entry" '. + [$e | .round += 1]' <<<"$next")
    else
      echo "  $channel $name: broken"
      results=$(jq -c --arg c "$channel" --arg n "$name" '.[$c][$n] = null' <<<"$results")
    fi
  done < <(jq -c '.[]' <<<"$pending")
  pending=$next
done

jq -S . <<<"$results" > nix/verified.json
echo "main: $(jq '.main | length' nix/verified.json) changed, stable: $(jq '.stable | length' nix/verified.json) changed"
