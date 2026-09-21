mkDwl: {
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  cfg = config.programs.dwl;
  shared = import ./options.nix {inherit lib pkgs cfg mkDwl;};
  session = shared.sessionForPackage cfg.package;
  sessionPackage = shared.sessionPackageForSession session;
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

  config = lib.mkMerge [
    {lib.dwl = import ./config.nix {inherit lib;};}
    (lib.mkIf cfg.enable (lib.mkMerge [
      {
        assertions = shared.assertions shared.package;
        inherit (shared) warnings;
        home.packages = [cfg.package session] ++ cfg.extraPackages;
      }
      (lib.optionalAttrs (options ? xdg) {
        xdg.dataFile."wayland-sessions/dwl.desktop".source = "${sessionPackage}/share/wayland-sessions/dwl.desktop";
      })
      (lib.optionalAttrs (options ? systemd) {
        systemd.user.targets.dwl-session = lib.mkIf pkgs.stdenv.isLinux {
          Unit = {
            Description = "dwl session";
            Documentation = ["man:systemd.special(7)"];
            BindsTo = ["graphical-session.target"];
            Wants = ["graphical-session-pre.target"];
            After = ["graphical-session-pre.target"];
          };
        };
      })
    ]))
  ];

  _class = "homeManager";
}
