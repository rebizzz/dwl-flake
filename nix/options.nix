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

  declarative = ["settings" "keybinds" "modKey" "rules" "monitors" "autostart" "extraConfig"];
in {
  options = {
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

    extraBuildInputs = mkOption {
      type = with types; listOf package;
      default = [];
      description = "Libraries a patch needs that aren't detected.";
    };
  };

  package = let
    dwl = (mkDwl pkgs cfg.channel).override {
      inherit (cfg) patches configH extraBuildInputs settings keybinds defaultKeybinds modKey autostart extraConfig;
      inherit (cfg) rules monitors;
      enableXWayland = cfg.xwayland;
    };
  in
    if cfg.statusCommand == null
    then dwl
    else
      pkgs.symlinkJoin {
        name = "${dwl.name}-with-status";
        paths = [dwl dwl.man];
        postBuild = ''
          rm $out/bin/dwl
          cat > $out/bin/dwl <<EOF
          #!${pkgs.runtimeShell}
          ${pkgs.writeShellScript "dwl-status" cfg.statusCommand} | exec ${lib.getExe dwl} "\$@"
          EOF
          chmod +x $out/bin/dwl
        '';
        inherit (dwl) passthru;
        meta = dwl.meta // {outputsToInstall = ["out"];};
      };

  assertions = build:
    map (message: {
      assertion = false;
      inherit message;
    })
    build.configErrors or [];

  warnings =
    lib.optional (cfg.configH != null && lib.any (o: cfg.${o} != {} && cfg.${o} != [] && cfg.${o} != "" && cfg.${o} != null) declarative) "programs.dwl.configH is set, so ${lib.concatStringsSep ", " declarative} are ignored.";
}
