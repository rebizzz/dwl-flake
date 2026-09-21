{pkgs}: let
  lib = pkgs.lib;
  index = lib.importJSON ./patches.json;

  formatPatch = name: data: let
    mainCompat = (data.default.main or null) != null;
    stableCompat = (data.default.stable or null) != null;
    channels = lib.concatStringsSep ", " (
      (lib.optional mainCompat "main")
      ++ (lib.optional stableCompat "stable")
    );
    req =
      if (data.requires or null) != null
      then "`" + data.requires + "`"
      else "-";
    desc =
      if (data.description or null) != null
      then lib.replaceStrings ["\n" "\r" "|"] [" " " " "\\|"] data.description
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
