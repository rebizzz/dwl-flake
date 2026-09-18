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
      package = lib.mkOption {
        type = lib.types.package;
        default = shared.package;
        defaultText = lib.literalMD "dwl built from the options above";
        description = "The dwl package to install.";
      };
    };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];
    lib.dwl = import ./config.nix {inherit lib;};
  };
}
