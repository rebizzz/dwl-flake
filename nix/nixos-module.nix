{
  mkDwl,
  homeModule,
  homeStylixModule,
}: {
  config,
  lib,
  pkgs,
  options,
  modulesPath,
  ...
}: let
  cfg = config.programs.dwl;
  shared = import ./options.nix {inherit lib pkgs cfg mkDwl;};

  userDwl = pkgs.writeShellScriptBin "dwl" ''
    for dwl in "/etc/profiles/per-user/$USER/bin/dwl" "$HOME/.nix-profile/bin/dwl" "$HOME/.local/state/nix/profile/bin/dwl"; do
      [ -x "$dwl" ] && exec "$dwl" "$@"
    done
    exec ${lib.getExe shared.package} "$@"
  '';

  session = shared.sessionForPackage cfg.package;
  sessionPackage = shared.sessionPackageForSession session;
in {
  disabledModules = ["programs/wayland/dwl.nix"];

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
        default =
          if cfg.useHomeManagerBuild
          then userDwl
          else shared.package;
        defaultText = lib.literalMD "dwl built from the options above";
        description = "The dwl package to use.";
      };

      useHomeManagerBuild = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start the dwl each user builds with the Home Manager module. Users without one get the build from these options.";
      };

      polkitAgent.enable = lib.mkEnableOption "a polkit authentication agent in the dwl session";

      keyring.enable = lib.mkEnableOption "the oo7 secret service in the dwl session";
    };

  config = lib.mkMerge [
    {lib.dwl = import ./config.nix {inherit lib;};}
    (lib.mkIf cfg.enable (lib.mkMerge [
      {
        assertions = shared.assertions shared.package;
        warnings =
          shared.warnings
          ++ lib.optional (
            lib.elem "nvidia" config.services.xserver.videoDrivers
            && lib.versionOlder (lib.versions.major (lib.getVersion config.hardware.nvidia.package)) "551"
          ) "Using dwl with Nvidia driver version <= 550 may result in a broken system. Configure hardware.nvidia.package to use a newer version.";

        environment.etc."xdg/dwl-session".source = "${session}/bin/dwl-session";
        environment.systemPackages = [cfg.package session] ++ cfg.extraPackages ++ lib.optional cfg.keyring.enable pkgs.oo7;
        services.displayManager.sessionPackages = [sessionPackage];

        # Which portal backend answers for the dwl session. Enabling portals at
        # all is left to the configuration, as is everything else a desktop
        # wants; wayland-session.nix below covers the wayland plumbing.
        xdg.portal.config.dwl = lib.mkIf config.xdg.portal.enable {
          default = lib.mkDefault ["wlr" "gtk"];
          "org.freedesktop.impl.portal.ScreenCast" = lib.mkDefault "wlr";
          "org.freedesktop.impl.portal.Screenshot" = lib.mkDefault "wlr";
          "org.freedesktop.impl.portal.Inhibit" = lib.mkDefault "none";
        };

        systemd.user.targets.dwl-session = {
          description = "dwl session";
          documentation = ["man:systemd.special(7)"];
          bindsTo = ["graphical-session.target"];
          wants = ["graphical-session-pre.target"];
          after = ["graphical-session-pre.target"];
        };

        systemd.user.services.dwl-polkit-agent = lib.mkIf cfg.polkitAgent.enable {
          description = "Polkit authentication agent for dwl";
          wantedBy = ["dwl-session.target"];
          partOf = ["graphical-session.target"];
          after = ["graphical-session.target"];
          serviceConfig = {
            ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };
      }
      (import "${modulesPath}/programs/wayland/wayland-session.nix" {
        inherit lib pkgs;
        enableXWayland = cfg.xwayland;
      })
    ]))
    (lib.optionalAttrs (options ? home-manager) {
      home-manager.sharedModules = [homeModule] ++ lib.optional (options ? stylix) homeStylixModule;
    })
  ];

  _class = "nixos";
}
