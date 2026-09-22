{
  lib,
  pkgs,
  cfg,
  mkDwl,
}: let
  inherit (lib) mkOption types literalExpression;

  rule = types.submodule {
    options = {
      id = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Wayland app_id to match.";
      };
      title = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Window title to match.";
      };
      tags = mkOption {
        type = types.listOf (types.ints.between 1 31);
        default = [];
        description = "Tags to put the window on. Empty means the current ones.";
      };
      floating = mkOption {
        type = types.bool;
        default = false;
        description = "Start the window floating.";
      };
      monitor = mkOption {
        type = types.int;
        default = -1;
        description = "Monitor index, or -1 for the current one.";
      };
    };
  };

  monitor = types.submodule {
    options = {
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Output name, e.g. eDP-1.";
      };
      mfact = mkOption {
        type = types.numbers.between 0.05 0.95;
        default = 0.55;
        description = "Size of the master area.";
      };
      nmaster = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Number of windows in the master area.";
      };
      scale = mkOption {
        type = types.numbers.positive;
        default = 1;
        description = "Output scale.";
      };
      layout = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "Index into layouts.";
      };
      transform = mkOption {
        type = types.enum ["normal" "90" "180" "270" "flipped" "flipped_90" "flipped_180" "flipped_270"];
        default = "normal";
        description = "Output rotation.";
      };
      x = mkOption {
        type = types.int;
        default = -1;
        description = "Position, or -1 to place automatically.";
      };
      y = mkOption {
        type = types.int;
        default = -1;
        description = "Position, or -1 to place automatically.";
      };
    };
  };

  declarative = ["settings" "keybinds" "buttons" "axes" "modKey" "rules" "monitors" "autostart" "extraConfig"];

  typed = import ./typed.nix {inherit lib;};
  inherit (import ./config.nix {inherit lib;}) c;

  sessionForPackage = pkg:
    pkgs.writeShellScriptBin "dwl-session" ''
      ${cfg.extraSessionCommands}
      export XDG_CURRENT_DESKTOP=''${XDG_CURRENT_DESKTOP:-dwl}
      export XDG_SESSION_DESKTOP=''${XDG_SESSION_DESKTOP:-dwl}
      export XDG_SESSION_TYPE=wayland
      ${lib.getExe pkg} ${lib.escapeShellArgs cfg.extraOptions} -s ${pkgs.writeShellScript "dwl-startup" ''
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
        systemctl --user start dwl-session.target
        ${cfg.startupCommand}
      ''} "$@"
      status=$?
      systemctl --user stop dwl-session.target
      exit $status
    '';

  sessionPackageForSession = sess:
    (pkgs.writeTextDir "share/wayland-sessions/dwl.desktop" ''
      [Desktop Entry]
      Name=dwl
      Comment=dwm for Wayland
      Exec=${lib.getExe sess}
      Type=Application
      DesktopNames=dwl
    '')
    // {providedSessions = ["dwl"];};

  session = sessionForPackage cfg.package;
  sessionPackage = sessionPackageForSession session;
in {
  options =
    typed.options
    // {
      channel = mkOption {
        type = types.enum ["main" "stable"];
        default = "main";
        description = "Build dwl main or the latest dwl release.";
      };

      patches = mkOption {
        type = with types; listOf (oneOf [path package str]);
        default = [];
        example = literalExpression ''[ "pertag" "movestack" ./my-fix.patch ]'';
        description = "Patches to apply. A name picks the file from dwl-patches that applies to the channel and adds its dependencies.";
      };

      modKey = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "Super";
        description = "What `Mod` means in keybinds and in dwl's defaults: Super, Alt, Ctrl or Shift.";
      };

      keybinds = mkOption {
        type = with types; attrsOf (either str (attrsOf anything));
        default = {};
        example = literalExpression ''
          {
            "Mod+Return".spawn = "foot";
            "Mod+q" = "killclient";
            "Mod+1".view = 1;
            "Mod+Shift+1".tag = 1;
          }
        '';
        description = "Keybinds as `\"Modifiers+keysym\" = action`.";
      };

      defaultKeybinds = mkOption {
        type = types.bool;
        default = true;
        description = "Keep dwl's default keybinds next to yours.";
      };

      rules = mkOption {
        type = types.listOf rule;
        default = [];
        example = literalExpression ''[ { id = "firefox"; tags = [ 2 ]; } ]'';
        description = "Window rules.";
      };

      monitors = mkOption {
        type = types.listOf monitor;
        default = [];
        example = literalExpression ''[ { name = "eDP-1"; scale = 1.5; } ]'';
        description = "Monitor rules. A catch-all rule is added at the end.";
      };

      autostart = mkOption {
        type = with types; listOf str;
        default = [];
        example = ["waybar"];
        description = "Commands started with dwl. Adds the autostart patch.";
      };

      settings = mkOption {
        type = with types; attrsOf anything;
        default = {};
        example = literalExpression ''{ borderpx = 2; focuscolor = "#89b4fa"; }'';
        description = "Any variable or define from config.def.h, including ones added by patches.";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "C code added to the top of config.h.";
      };

      configH = mkOption {
        type = with types; nullOr (either path lines);
        default = null;
        example = literalExpression "./config.h";
        description = "Your own config.h. The declarative options are ignored when set.";
      };

      statusCommand = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "while true; do date +%H:%M; sleep 30; done";
        description = "Shell command whose output lines become the status text in the bar patch.";
      };

      xwayland = lib.mkEnableOption "XWayland support" // {default = true;};

      buttons = mkOption {
        type = with types; attrsOf (either str (attrsOf anything));
        default = {};
        example = lib.literalExpression ''
          {
            "Mod+left".moveresize = "move";
            "Mod+right".moveresize = "resize";
            "Mod+middle" = "togglefloating";
          }
        '';
        description = "Mouse bindings as `\"Modifiers+button\" = action`. Buttons: left, right, middle, side, extra.";
      };

      axes = mkOption {
        type = with types; attrsOf (either str (attrsOf anything));
        default = {};
        example = lib.literalExpression ''
          {
            "Mod+up".spawn = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            "Mod+down".spawn = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          }
        '';
        description = "Scroll wheel bindings as `\"Modifiers+direction\" = action` (main only). Directions: up, down, left, right. Replaces dwl's example bindings.";
      };

      defaultButtons = mkOption {
        type = types.bool;
        default = true;
        description = "Keep dwl's default mouse bindings next to yours.";
      };

      environment = mkOption {
        type = with types; attrsOf str;
        default = {};
        example = {NIXOS_OZONE_WL = "1";};
        description = "Environment variables set for dwl and everything it starts.";
      };

      extraPackages = mkOption {
        type = with types; listOf package;
        default = [];
        example = lib.literalExpression "with pkgs; [ foot wmenu swaybg grim slurp ]";
        description = "Programs installed alongside dwl. dwl's own keybinds launch foot and wmenu, so add them here if you keep the default keybinds.";
      };

      extraBuildInputs = mkOption {
        type = with types; listOf package;
        default = [];
        description = "Libraries a patch needs that aren't detected.";
      };

      extraSessionCommands = mkOption {
        type = types.lines;
        default = "";
        example = "export MOZ_ENABLE_WAYLAND=1";
        description = "Shell commands run before dwl starts.";
      };

      extraOptions = mkOption {
        type = with types; listOf str;
        default = [];
        example = ["-d"];
        description = "Command line arguments passed to dwl.";
      };

      startupCommand = mkOption {
        type = types.lines;
        default = "";
        example = "exec waybar";
        description = "Shell commands run once dwl is up, with the Wayland environment set. Its standard input is dwl's status output.";
      };
    };

  package = let
    dwl = (mkDwl pkgs cfg.channel).override {
      inherit (cfg) patches configH extraBuildInputs keybinds defaultKeybinds buttons defaultButtons axes modKey autostart extraConfig;
      settings = typed.toSettings c cfg // cfg.settings;
      inherit (cfg) rules monitors;
      enableXWayland = cfg.xwayland;
    };
  in
    if cfg.statusCommand == null && cfg.environment == {}
    then dwl
    else
      pkgs.symlinkJoin {
        name = "${dwl.name}-wrapped";
        paths = [dwl dwl.man];
        postBuild = ''
          rm $out/bin/dwl
          cat > $out/bin/dwl <<EOF
          #!${pkgs.runtimeShell}
          ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") cfg.environment)}
          ${
            if cfg.statusCommand == null
            then "exec ${lib.getExe dwl} \"\\$@\""
            else "${pkgs.writeShellScript "dwl-status" cfg.statusCommand} | exec ${lib.getExe dwl} \"\\$@\""
          }
          EOF
          chmod +x $out/bin/dwl
        '';
        inherit (dwl) passthru;
        meta = dwl.meta // {outputsToInstall = ["out"];};
      };

  inherit session sessionPackage sessionForPackage sessionPackageForSession;

  assertions = build:
    map (message: {
      assertion = false;
      inherit message;
    })
    build.configErrors or [];

  warnings =
    lib.optional (cfg.configH != null && lib.any (o: cfg.${o} != {} && cfg.${o} != [] && cfg.${o} != "" && cfg.${o} != null) declarative) "programs.dwl.configH is set, so ${lib.concatStringsSep ", " declarative} are ignored.";
}
