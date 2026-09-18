mkDwl: {
  config,
  lib,
  pkgs,
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
in {
  options.programs.dwl =
    shared.options
    // {
      useHomeManagerBuild = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Start the dwl each user builds with the Home Manager module, so the
          system only provides the session. Falls back to the build from the
          options here for users without one.
        '';
      };
    };

  config = {
    programs.dwl.package = lib.mkDefault (
      if cfg.useHomeManagerBuild
      then userDwl
      else shared.package
    );
    lib.dwl = import ./config.nix {inherit lib;};
  };
}
