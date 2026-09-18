{
  lib,
  pkgs,
  cfg,
  mkDwl,
}: let
  inherit (lib) mkOption types literalExpression;
in {
  options = {
    channel = mkOption {
      type = types.enum ["main" "stable"];
      default = "main";
      description = "Build dwl main (tracked continuously) or the latest dwl release.";
    };

    patches = mkOption {
      type = with types; listOf (oneOf [path package str]);
      default = [];
      example = literalExpression ''[ "bar" "pertag" ./my-fix.patch ]'';
      description = ''
        Patches to apply. A plain name picks the variant from dwl-patches that
        applies to the chosen channel and adds its build dependencies.
      '';
    };

    modKey = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "Super";
      description = "The key `Mod` stands for in keybinds and in dwl's defaults. Super, Alt, Ctrl or Shift.";
    };

    keybinds = mkOption {
      type = with types; attrsOf (either str attrs);
      default = {};
      example = literalExpression ''
        {
          "Mod+Return" = { spawn = "foot"; };
          "Mod+d" = { spawn = [ "fuzzel" ]; };
          "Mod+q" = "killclient";
          "Mod+Shift+e" = "quit";
          "Mod+h" = { setmfact = -0.05; };
          "Mod+F1" = { view = 1; };
          "Mod+Shift+F1" = { tag = 1; };
          "Mod+m" = { setlayout = 2; };
          "Mod+comma" = { focusmon = "left"; };
          "Mod+b" = { fn = "togglebar"; };
        }
      '';
      description = ''
        Keybinds as `"Modifiers+keysym" = action`. They take priority over
        dwl's defaults with the same keys.
      '';
    };

    defaultKeybinds = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Keep dwl's default keybinds next to your own. When false, only yours
        are used, plus Ctrl+Alt+F1..F12 and Ctrl+Alt+BackSpace.
      '';
    };

    rules = mkOption {
      type = with types; listOf attrs;
      default = [];
      example = literalExpression ''
        [
          { id = "firefox"; tags = [ 2 ]; }
          { id = "pavucontrol"; floating = true; }
          { title = "Picture-in-Picture"; floating = true; }
        ]
      '';
      description = "Window rules. Fields: id, title, tags (list of 1-based tags), floating, monitor.";
    };

    monitors = mkOption {
      type = with types; listOf attrs;
      default = [];
      example = literalExpression ''[ { name = "eDP-1"; scale = 1.5; } ]'';
      description = ''
        Monitor rules. Fields: name, mfact, nmaster, scale, layout (index into
        layouts), transform, x, y. A catch-all rule is added at the end.
      '';
    };

    autostart = mkOption {
      type = with types; listOf str;
      default = [];
      example = ["waybar" "mako" "swaybg -i ~/wall.png"];
      description = "Shell commands started with dwl and stopped when it exits. Adds the autostart patch.";
    };

    settings = mkOption {
      type = with types; attrsOf anything;
      default = {};
      example = literalExpression ''
        {
          borderpx = 2;
          sloppyfocus = true;
          focuscolor = "#89b4faff";
          repeat_rate = 50;
          natural_scrolling = true;
          accel_profile = "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
          xkb_rules = { layout = "us,de"; options = "grp:alt_shift_toggle"; };
          TAGCOUNT = 9;
        }
      '';
      description = ''
        Any variable or `#define` from config.def.h, including the ones your
        patches add, by its C name.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "C code placed at the top of config.h, for your own helpers and command arrays.";
    };

    configH = mkOption {
      type = with types; nullOr (either path lines);
      default = null;
      example = literalExpression "./config.h";
      description = "A complete config.h, as a file or text. Everything above except patches is ignored when set.";
    };

    xwayland = lib.mkEnableOption "XWayland support" // {default = true;};

    extraBuildInputs = mkOption {
      type = with types; listOf package;
      default = [];
      description = "Extra build inputs, for patches whose dependencies aren't detected.";
    };
  };

  package = (mkDwl pkgs cfg.channel).override {
    inherit (cfg) patches configH extraBuildInputs settings keybinds defaultKeybinds modKey rules monitors autostart extraConfig;
    enableXWayland = cfg.xwayland;
  };
}
