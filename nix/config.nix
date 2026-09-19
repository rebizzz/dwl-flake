{lib}: let
  inherit (lib) concatMapStringsSep concatStringsSep mapAttrsToList isAttrs isList isString isInt isFloat isBool;

  c = value: {
    _type = "dwl-c";
    inherit value;
  };
  isC = v: isAttrs v && (v._type or null) == "dwl-c";

  cFloat = f: let
    s = builtins.toJSON f;
  in "${s}${lib.optionalString (builtins.match ".*[.e].*" s == null) ".0"}f";

  cString = s: "\"${lib.escape ["\\" "\""] (lib.replaceStrings ["\n"] ["\\n"] s)}\"";

  hexColor = s: let
    m = builtins.match "#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?" s;
  in
    if m == null
    then null
    else "COLOR(0x${lib.elemAt m 0}${
      if lib.elemAt m 1 == null
      then "ff"
      else lib.elemAt m 1
    })";

  toC = v:
    if v == null
    then "NULL"
    else if isBool v
    then
      (
        if v
        then "1"
        else "0"
      )
    else if isInt v
    then toString v
    else if isFloat v
    then cFloat v
    else if isString v
    then
      (
        if hexColor v != null
        then hexColor v
        else if builtins.match "[A-Z][A-Z0-9_]+" v != null
        then v
        else cString v
      )
    else if isC v
    then v.value
    else if isList v
    then "{ ${concatMapStringsSep ", " toC v} }"
    else "{ ${concatStringsSep ", " (mapAttrsToList (k: x: ".${k} = ${toC x}") v)} }";

  modifiers = {
    super = "WLR_MODIFIER_LOGO";
    logo = "WLR_MODIFIER_LOGO";
    mod4 = "WLR_MODIFIER_LOGO";
    alt = "WLR_MODIFIER_ALT";
    mod1 = "WLR_MODIFIER_ALT";
    ctrl = "WLR_MODIFIER_CTRL";
    control = "WLR_MODIFIER_CTRL";
    shift = "WLR_MODIFIER_SHIFT";
    mod = "MODKEY";
  };

  parseCombo = combo: let
    parts = lib.splitString "+" combo;
    key = lib.last parts;
    mods = map (m: modifiers.${lib.toLower m} or (throw "dwl keybinds: unknown modifier '${m}' in '${combo}'")) (lib.init parts);
  in {
    mods =
      if mods == []
      then "0"
      else concatStringsSep "|" mods;
    key =
      if lib.hasPrefix "XKB_KEY_" key
      then key
      else "XKB_KEY_${key}";
  };

  tagMask = t:
    if t == "all"
    then "~0"
    else if isList t
    then
      (
        if t == []
        then "0"
        else concatMapStringsSep " | " tagMask t
      )
    else "1 << ${toString (t - 1)}";

  direction = d:
    if isString d
    then "WLR_DIRECTION_${lib.toUpper d}"
    else toString d;

  spawnArg = cmd:
    if isString cmd
    then "{ .v = (const char*[]){ \"/bin/sh\", \"-c\", ${cString cmd}, NULL } }"
    else "{ .v = (const char*[]){ ${concatMapStringsSep ", " cString cmd}, NULL } }";

  genericArg = a:
    if a == null || a == true
    then "{0}"
    else if isInt a
    then "{ .i = ${toString a} }"
    else if isFloat a
    then "{ .f = ${cFloat a} }"
    else if isC a
    then a.value
    else toC a;

  argFor = fn: a:
    if a == null || a == true
    then "{0}"
    else if fn == "spawn"
    then spawnArg a
    else if lib.elem fn ["view" "toggleview" "tag" "toggletag"]
    then "{ .ui = ${tagMask a} }"
    else if lib.elem fn ["focusmon" "tagmon"]
    then "{ .i = ${direction a} }"
    else if fn == "setlayout"
    then "{ .v = &layouts[${toString a}] }"
    else if fn == "chvt"
    then "{ .ui = ${toString a} }"
    else genericArg a;

  keyEntry = combo: action: let
    k = parseCombo combo;
    call =
      if isString action
      then {
        fn = action;
        arg = "{0}";
      }
      else if action ? fn
      then {
        inherit (action) fn;
        arg = genericArg (action.arg or null);
      }
      else if lib.length (lib.attrNames action) == 1
      then let
        fn = lib.head (lib.attrNames action);
      in {
        inherit fn;
        arg = argFor fn action.${fn};
      }
      else throw "dwl keybinds: '${combo}' should be a function name, { <function> = <arg>; } or { fn = ...; arg = ...; }";
  in "\t{ ${k.mods}, ${k.key}, ${call.fn}, ${call.arg} },";

  mouseButtons = {
    left = "BTN_LEFT";
    right = "BTN_RIGHT";
    middle = "BTN_MIDDLE";
    side = "BTN_SIDE";
    extra = "BTN_EXTRA";
  };

  buttonEntry = clickRegion: combo: action: let
    parts = lib.splitString "+" combo;
    k = parseCombo (concatStringsSep "+" (lib.init parts ++ ["x"]));
    button = mouseButtons.${lib.toLower (lib.last parts)};
    fn = actionFunction action;
    arg =
      if isString action
      then "{0}"
      else if action ? fn
      then genericArg (action.arg or null)
      else if fn == "moveresize"
      then "{ .ui = ${
        if action.moveresize == "move"
        then "CurMove"
        else "CurResize"
      } }"
      else argFor fn action.${fn};
  in "\t{ ${lib.optionalString clickRegion "ClkClient, "}${k.mods}, ${button}, ${fn}, ${arg} },";

  axisDirections = {
    up = "AxisUp";
    down = "AxisDown";
    left = "AxisLeft";
    right = "AxisRight";
  };

  axisEntry = combo: action: let
    parts = lib.splitString "+" combo;
    k = parseCombo (concatStringsSep "+" (lib.init parts ++ ["x"]));
    fn = actionFunction action;
    arg =
      if isString action
      then "{0}"
      else if action ? fn
      then genericArg (action.arg or null)
      else argFor fn action.${fn};
  in "\t{ ${k.mods}, ${axisDirections.${lib.toLower (lib.last parts)}}, ${fn}, ${arg} },";

  vtKeys =
    ["\t{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_BackSpace, quit, {0} },"]
    ++ map (n: "\t{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F${toString n}, chvt, { .ui = ${toString n} } },") (lib.range 1 12);

  ruleEntry = r: "\t{ ${toC (r.id or null)}, ${toC (r.title or null)}, ${tagMask (r.tags or [])}, ${toC (r.floating or false)}, ${toString (r.monitor or (-1))} },";

  monitorEntry = m: "\t{ ${toC (m.name or null)}, ${toC (m.mfact or 0.55)}, ${toString (m.nmaster or 1)}, ${toC ((m.scale or 1) * 1.0)}, &layouts[${toString (m.layout or 0)}], WL_OUTPUT_TRANSFORM_${lib.toUpper (m.transform or "normal")}, ${toString (m.x or (-1))}, ${toString (m.y or (-1))} },";

  autostartEntries = cmds: concatStringsSep " " (map (cmd: "\"/bin/sh\", \"-c\", ${cString cmd}, NULL,") cmds) + " NULL";
  actionFunction = action:
    if isString action
    then action
    else if action ? fn
    then action.fn
    else lib.head (lib.attrNames action);

  comboErrors = combo: let
    parts = lib.splitString "+" combo;
  in
    lib.optional (lib.last parts == "") "keybind '${combo}' has no key after the last '+'"
    ++ map (m: "keybind '${combo}': unknown modifier '${m}', use Mod, Super, Alt, Ctrl or Shift")
    (lib.filter (m: !(modifiers ? ${lib.toLower m})) (lib.init parts));

  actionErrors = combo: action:
    lib.optional (!(isString action || action ? fn || lib.length (lib.attrNames action) == 1))
    "keybind '${combo}' should be a function name, { <function> = <arg>; } or { fn = ...; arg = ...; }";
in {
  inherit c;

  errors = cfg:
    lib.optional (cfg.modKey != null && (!(modifiers ? ${lib.toLower cfg.modKey}) || lib.toLower cfg.modKey == "mod"))
    "modKey '${cfg.modKey}' isn't a modifier, use Super, Alt, Ctrl or Shift"
    ++ lib.concatLists (mapAttrsToList (combo: action: comboErrors combo ++ actionErrors combo action) cfg.keybinds)
    ++ lib.concatLists (mapAttrsToList (combo: action: let
      parts = lib.splitString "+" combo;
    in
      comboErrors (concatStringsSep "+" (lib.init parts ++ ["x"]))
      ++ lib.optional (!(mouseButtons ? ${lib.toLower (lib.last parts)})) "mouse binding '${combo}': unknown button '${lib.last parts}', use left, right, middle, side or extra"
      ++ lib.optional (action ? moveresize && !(lib.elem action.moveresize ["move" "resize"])) "mouse binding '${combo}': moveresize takes \"move\" or \"resize\""
      ++ actionErrors combo action)
    cfg.buttons)
    ++ lib.concatLists (mapAttrsToList (combo: action: let
      parts = lib.splitString "+" combo;
    in
      comboErrors (concatStringsSep "+" (lib.init parts ++ ["x"]))
      ++ lib.optional (!(axisDirections ? ${lib.toLower (lib.last parts)})) "scroll binding '${combo}': unknown direction '${lib.last parts}', use up, down, left or right"
      ++ actionErrors combo action)
    cfg.axes);

  functions = cfg: lib.unique (mapAttrsToList (_: actionFunction) (cfg.keybinds // cfg.buttons // cfg.axes));

  isEmpty = cfg:
    cfg.settings
    == {}
    && cfg.keybinds == {}
    && cfg.defaultKeybinds
    && cfg.modKey == null
    && cfg.rules == []
    && cfg.monitors == []
    && cfg.autostart == []
    && cfg.buttons == {}
    && cfg.defaultButtons
    && cfg.axes == {}
    && cfg.extraConfig == "";

  render = cfg: let
    keyLines = mapAttrsToList keyEntry cfg.keybinds;
    buttonLines = mapAttrsToList (buttonEntry cfg.buttonClickRegion) cfg.buttons;
  in {
    define =
      lib.optionalAttrs (cfg.modKey != null) {MODKEY = (parseCombo "${cfg.modKey}+x").mods;}
      // lib.mapAttrs (_: toC) (lib.filterAttrs (n: _: n == lib.toUpper n) cfg.settings);

    replace =
      lib.mapAttrs (_: toC) (lib.filterAttrs (n: _: n != lib.toUpper n) cfg.settings)
      // lib.optionalAttrs (!cfg.defaultKeybinds) {keys = "{\n${concatStringsSep "\n" (keyLines ++ vtKeys)}\n}";}
      // lib.optionalAttrs (cfg.axes != {}) {axes = "{\n${concatStringsSep "\n" (mapAttrsToList axisEntry cfg.axes)}\n}";}
      // lib.optionalAttrs (!cfg.defaultButtons) {buttons = "{\n${concatStringsSep "\n" buttonLines}\n}";}
      // lib.optionalAttrs (cfg.rules != []) {rules = "{\n${concatMapStringsSep "\n" ruleEntry cfg.rules}\n}";}
      // lib.optionalAttrs (cfg.monitors != []) {monrules = "{\n${concatMapStringsSep "\n" monitorEntry (cfg.monitors ++ [{}])}\n}";}
      // lib.optionalAttrs (cfg.autostart != []) {autostart = "{ ${autostartEntries cfg.autostart} }";};

    prepend =
      lib.optionalAttrs (cfg.defaultKeybinds && keyLines != []) {keys = concatStringsSep "\n" keyLines;}
      // lib.optionalAttrs (cfg.defaultButtons && buttonLines != []) {buttons = concatStringsSep "\n" buttonLines;};

    extra = cfg.extraConfig;
  };
}
