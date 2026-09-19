{lib}: let
  inherit (lib) mkOption types;

  opt = type: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      inherit description;
    };

  color = types.strMatching "#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})";

  enums = {
    scrollMethod = {
      none = "LIBINPUT_CONFIG_SCROLL_NO_SCROLL";
      two-finger = "LIBINPUT_CONFIG_SCROLL_2FG";
      edge = "LIBINPUT_CONFIG_SCROLL_EDGE";
      on-button-down = "LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN";
    };
    clickMethod = {
      none = "LIBINPUT_CONFIG_CLICK_METHOD_NONE";
      button-areas = "LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS";
      clickfinger = "LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER";
    };
    sendEvents = {
      enabled = "LIBINPUT_CONFIG_SEND_EVENTS_ENABLED";
      disabled = "LIBINPUT_CONFIG_SEND_EVENTS_DISABLED";
      disabled-on-external-mouse = "LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE";
    };
    accelProfile = {
      flat = "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
      adaptive = "LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE";
    };
    tapButtonMap = {
      left-right-middle = "LIBINPUT_CONFIG_TAP_MAP_LRM";
      left-middle-right = "LIBINPUT_CONFIG_TAP_MAP_LMR";
    };
    logLevel = {
      silent = "WLR_SILENT";
      error = "WLR_ERROR";
      info = "WLR_INFO";
      debug = "WLR_DEBUG";
    };
  };

  enumOpt = name: description: opt (types.enum (lib.attrNames enums.${name})) description;

  layout = types.submodule {
    options = {
      symbol = mkOption {
        type = types.str;
        description = "Symbol shown for the layout.";
      };
      arrange = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Arrange function, e.g. `tile` or `monocle`. `null` means floating.";
      };
    };
  };
in {
  options = {
    appearance = {
      sloppyFocus = opt types.bool "Focus follows the mouse. dwl default: `true`.";
      bypassSurfaceVisibility = opt types.bool "Idle inhibitors disable idle tracking even when their surface isn't visible. dwl default: `false`.";
      borderWidth = opt types.ints.unsigned "Window border width in pixels. dwl default: `1`.";
      snap = opt types.ints.unsigned "Snap distance in pixels when moving floating windows (main only). dwl default: `32`.";
      colors = {
        root = opt color "Background color. dwl default: `#222222`.";
        border = opt color "Border of unfocused windows. dwl default: `#444444`. Removed by the bar patch.";
        focus = opt color "Border of the focused window. dwl default: `#005577`. Removed by the bar patch.";
        urgent = opt color "Border of urgent windows. dwl default: `#ff0000`. Removed by the bar patch.";
        fullscreenBackground = opt (types.either color (types.listOf types.float)) "Background behind fullscreen windows, as a color or four floats. dwl default: black.";
      };
    };

    tagCount = opt (types.ints.between 1 31) "Number of tags. dwl default: `9`.";

    logLevel = enumOpt "logLevel" "wlroots log level. dwl default: `error`.";

    layouts = mkOption {
      type = types.nullOr (types.listOf layout);
      default = null;
      example = lib.literalExpression ''
        [
          { symbol = "[]="; arrange = "tile"; }
          { symbol = "><>"; }
          { symbol = "[M]"; arrange = "monocle"; }
        ]
      '';
      description = "Layouts, in order. `setlayout` indexes into this list. dwl default: tile, floating, monocle.";
    };

    input = {
      keyboard = {
        xkb = {
          rules = opt types.str "XKB rules.";
          model = opt types.str "XKB model.";
          layout = opt types.str "XKB layout, e.g. `us,de`.";
          variant = opt types.str "XKB variant.";
          options = opt types.str "XKB options, e.g. `caps:escape`.";
        };
        repeatRate = opt types.ints.unsigned "Key repeats per second. dwl default: `25`.";
        repeatDelay = opt types.ints.unsigned "Milliseconds before a key starts repeating. dwl default: `600`.";
      };

      touchpad = {
        tapToClick = opt types.bool "Tap to click. dwl default: `true`.";
        tapAndDrag = opt types.bool "Tap and drag. dwl default: `true`.";
        dragLock = opt types.bool "Drag lock. dwl default: `true`.";
        naturalScroll = opt types.bool "Natural scrolling. dwl default: `false`.";
        disableWhileTyping = opt types.bool "Disable the touchpad while typing. dwl default: `true`.";
        leftHanded = opt types.bool "Left-handed mode. dwl default: `false`.";
        middleButtonEmulation = opt types.bool "Emulate a middle click. dwl default: `false`.";
        scrollMethod = enumOpt "scrollMethod" "Scroll method. dwl default: `two-finger`.";
        clickMethod = enumOpt "clickMethod" "Click method. dwl default: `button-areas`.";
        sendEvents = enumOpt "sendEvents" "When the touchpad sends events. dwl default: `enabled`.";
        accelProfile = enumOpt "accelProfile" "Pointer acceleration profile. dwl default: `adaptive`.";
        accelSpeed = opt (types.numbers.between (-1.0) 1.0) "Pointer acceleration, from -1 to 1. dwl default: `0`.";
        tapButtonMap = enumOpt "tapButtonMap" "What 1, 2 and 3 finger taps click. dwl default: `left-right-middle`.";
      };
    };
  };

  toSettings = c: cfg: let
    a = cfg.appearance;
    kb = cfg.input.keyboard;
    tp = cfg.input.touchpad;
    enum = name: v:
      if v == null
      then null
      else c enums.${name}.${v};
    xkb = lib.filterAttrs (_: v: v != null) kb.xkb;
  in
    lib.filterAttrs (_: v: v != null) {
      sloppyfocus = a.sloppyFocus;
      bypass_surface_visibility = a.bypassSurfaceVisibility;
      borderpx = a.borderWidth;
      inherit (a) snap;
      rootcolor = a.colors.root;
      bordercolor = a.colors.border;
      focuscolor = a.colors.focus;
      urgentcolor = a.colors.urgent;
      fullscreen_bg = a.colors.fullscreenBackground;
      TAGCOUNT = cfg.tagCount;
      log_level = enum "logLevel" cfg.logLevel;
      layouts =
        if cfg.layouts == null
        then null
        else
          map (l:
            {inherit (l) symbol;}
            // lib.optionalAttrs (l.arrange != null) {arrange = c l.arrange;})
          cfg.layouts;
      xkb_rules =
        if xkb == {}
        then null
        else xkb;
      repeat_rate = kb.repeatRate;
      repeat_delay = kb.repeatDelay;
      tap_to_click = tp.tapToClick;
      tap_and_drag = tp.tapAndDrag;
      drag_lock = tp.dragLock;
      natural_scrolling = tp.naturalScroll;
      disable_while_typing = tp.disableWhileTyping;
      left_handed = tp.leftHanded;
      middle_button_emulation = tp.middleButtonEmulation;
      scroll_method = enum "scrollMethod" tp.scrollMethod;
      click_method = enum "clickMethod" tp.clickMethod;
      send_events_mode = enum "sendEvents" tp.sendEvents;
      accel_profile = enum "accelProfile" tp.accelProfile;
      accel_speed =
        if tp.accelSpeed == null
        then null
        else tp.accelSpeed * 1.0;
      button_map = enum "tapButtonMap" tp.tapButtonMap;
    };
}
