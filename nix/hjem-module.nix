mkDwl: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.dwl;
  shared = import ./options.nix {inherit lib pkgs cfg mkDwl;};
in {
  options.programs.dwl =
    shared.options
    // {
      enable = lib.mkEnableOption "dwl, a dwm-like Wayland compositor";

      finalConfig = lib.mkOption {
        type = lib.types.str;
        default = "${shared.package}/share/dwl/config.h";
        defaultText = lib.literalMD "the generated config.h";
        readOnly = true;
        description = "Path to the config.h dwl is built with.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = shared.package;
        defaultText = lib.literalMD "dwl built from the options above";
        description = "The dwl package to install.";
      };
    };

  config = lib.mkIf cfg.enable {
    packages = lib.throwIf (shared.package.configErrors != []) (lib.concatStringsSep "\n" shared.package.configErrors) [cfg.package];
  };

  _class = "hjem";
}
