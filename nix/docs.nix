{
  pkgs,
  nixpkgs,
  self,
}: let
  eval = nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [
      self.nixosModules.default
      {
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };

  doc = pkgs.nixosOptionsDoc {
    options.programs.dwl = eval.options.programs.dwl;
    transformOptions = opt: opt // {declarations = [];};
  };
in
  pkgs.runCommand "dwl-flake-docs.md" {} ''
    {
      echo "# Options"
      echo
      echo "Generated from the modules. Run \`nix run .#update-docs\` after changing an option."
      echo
      echo "All options live under \`programs.dwl\`, in the NixOS, Home Manager and hjem modules."
      echo "\`useHomeManagerBuild\`, \`extraSessionCommands\`, \`startupCommand\`, \`polkitAgent\` and \`keyring\` only exist in the NixOS module."
      echo
      cat -s ${doc.optionsCommonMark} | sed -e '/^## /s/\\\././g'
      echo
      echo "# Keybind actions"
      echo
      echo "Functions dwl itself provides, usable in \`keybinds\` and \`buttons\`. Patches add more."
      echo
      ${pkgs.lib.concatMapStrings (a: "echo \"- \\\`${a}\\\`\"\n") self.lib.actions.main}
    } > $out
  ''
