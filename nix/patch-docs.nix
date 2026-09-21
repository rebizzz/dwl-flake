{pkgs}: let
  lib = pkgs.lib;
  index = lib.importJSON ./patches.json;

  formatPatch = name: data: let
    mainCompat = (data.default.main or null) != null;
    stableCompat = (data.default.stable or null) != null;
    channels = let
      list = (lib.optional mainCompat "main") ++ (lib.optional stableCompat "stable");
    in
      if list == []
      then "unsupported"
      else lib.concatStringsSep ", " list;
    req =
      if (data.requires or null) != null
      then "`" + data.requires + "`"
      else "-";
    cleanDesc = desc: let
      noCode = lib.head (lib.splitString "```" desc);
      singleLine = lib.replaceStrings ["\n" "\r" "|"] [" " " " "\\|"] noCode;
      trimmed = lib.concatStringsSep " " (lib.filter (s: s != "") (lib.splitString " " singleLine));
    in
      trimmed;
    desc =
      if (data.description or null) != null
      then cleanDesc data.description
      else "";
  in "| `${name}` | ${channels} | ${req} | ${desc} |\n";

  sortedNames = lib.sort (a: b: a < b) (lib.attrNames index);
  patchRows = lib.concatMapStrings (name: formatPatch name index.${name}) sortedNames;
in
  pkgs.runCommand "patches.md" {} ''
    {
      echo "# Patches"
      echo
      echo "All patches available from \`dwl-patches\`, indexed automatically from \`nix/patches.json\`."
      echo "Run \`nix run .#update-docs\` to regenerate."
      echo
      echo "| Patch | Channels | Requires | Description |"
      echo "| --- | --- | --- | --- |"
      printf '%s' ${lib.escapeShellArg patchRows}
    } > $out
  ''
