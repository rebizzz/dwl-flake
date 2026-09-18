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

  vtKeys =
    ["\t{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_BackSpace, quit, {0} },"]
    ++ map (n: "\t{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F${toString n}, chvt, { .ui = ${toString n} } },") (lib.range 1 12);

  ruleEntry = r: "\t{ ${toC (r.id or null)}, ${toC (r.title or null)}, ${tagMask (r.tags or [])}, ${toC (r.floating or false)}, ${toString (r.monitor or (-1))} },";

  monitorEntry = m: "\t{ ${toC (m.name or null)}, ${toC (m.mfact or 0.55)}, ${toString (m.nmaster or 1)}, ${toC ((m.scale or 1) * 1.0)}, &layouts[${toString (m.layout or 0)}], WL_OUTPUT_TRANSFORM_${lib.toUpper (m.transform or "normal")}, ${toString (m.x or (-1))}, ${toString (m.y or (-1))} },";

  autostartEntries = cmds: concatStringsSep " " (map (cmd: "\"/bin/sh\", \"-c\", ${cString cmd}, NULL,") cmds) + " NULL";
in {
  inherit c;

  isEmpty = cfg:
    cfg.settings
    == {}
    && cfg.keybinds == {}
    && cfg.defaultKeybinds
    && cfg.modKey == null
    && cfg.rules == []
    && cfg.monitors == []
    && cfg.autostart == []
    && cfg.extraConfig == "";

  render = cfg: let
    keyLines = mapAttrsToList keyEntry cfg.keybinds;
  in {
    define =
      lib.optionalAttrs (cfg.modKey != null) {MODKEY = (parseCombo "${cfg.modKey}+x").mods;}
      // lib.mapAttrs (_: toC) (lib.filterAttrs (n: _: n == lib.toUpper n) cfg.settings);

    replace =
      lib.mapAttrs (_: toC) (lib.filterAttrs (n: _: n != lib.toUpper n) cfg.settings)
      // lib.optionalAttrs (!cfg.defaultKeybinds) {keys = "{\n${concatStringsSep "\n" (keyLines ++ vtKeys)}\n}";}
      // lib.optionalAttrs (cfg.rules != []) {rules = "{\n${concatMapStringsSep "\n" ruleEntry cfg.rules}\n}";}
      // lib.optionalAttrs (cfg.monitors != []) {monrules = "{\n${concatMapStringsSep "\n" monitorEntry (cfg.monitors ++ [{}])}\n}";}
      // lib.optionalAttrs (cfg.autostart != []) {autostart = "{ ${autostartEntries cfg.autostart} }";};

    prepend = lib.optionalAttrs (cfg.defaultKeybinds && keyLines != []) {keys = concatStringsSep "\n" keyLines;};

    extra = cfg.extraConfig;
  };
}
