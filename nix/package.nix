{
  lib,
  stdenv,
  pkgs,
  installShellFiles,
  libinput,
  libx11,
  libxcb,
  libxcb-wm,
  libxkbcommon,
  pixman,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
  writeText,
  xwayland,
  src,
  version,
  channel ? "main",
  dwlPatches ? null,
  enableXWayland ? true,
  patches ? [],
  configH ? null,
  extraBuildInputs ? [],
  wlrootsPackage ? null,
  settings ? {},
  keybinds ? {},
  defaultKeybinds ? true,
  modKey ? null,
  rules ? [],
  monitors ? [],
  autostart ? [],
  extraConfig ? "",
  buttons ? {},
  defaultButtons ? true,
  axes ? {},
  linkFarm,
}: let
  configLib = import ./config.nix {inherit lib;};
  declarative = {
    inherit settings keybinds defaultKeybinds modKey rules monitors autostart extraConfig buttons defaultButtons axes;
    buttonClickRegion = canInspect && tokens ? ClkClient;
  };
  edits = configLib.render declarative;
  editsDir = linkFarm "dwl-config-edits" (lib.concatLists (lib.mapAttrsToList (mode: entries:
    if mode == "extra"
    then
      lib.optional (entries != "") {
        name = "extra";
        path = writeText "dwl-config-extra" entries;
      }
    else
      lib.mapAttrsToList (name: text: {
        name = "${mode}/${name}";
        path = writeText "dwl-config-${mode}-${name}" text;
      })
      entries)
  edits));

  withAutostart = patches ++ lib.optional (autostart != [] && !lib.elem "autostart" patches) "autostart";
  requiredBy = p:
    if isPatchName p && dwlPatches != null
    then dwlPatches.requiredBy channel p
    else null;
  allPatches = lib.unique (lib.concatMap (p: lib.optional (requiredBy p != null) (requiredBy p) ++ [p]) withAutostart);

  isPatchName = p: builtins.isString p && !lib.hasPrefix "/" p;

  patchError = p: let
    entry = dwlPatches.index.${p} or null;
  in
    if dwlPatches == null
    then "dwl patch '${p}' was given by name, but no dwl-patches index is available"
    else if entry == null
    then "dwl patch '${p}' doesn't exist in dwl-patches"
    else if entry.default.${channel} == null
    then "dwl patch '${p}' has no version that applies to dwl ${channel} (${lib.concatStringsSep ", " (lib.attrNames entry.files)})${lib.optionalString (channel == "main" && entry.default.stable != null) ", but it works with channel = \"stable\""}"
    else null;
  patchErrors = lib.filter (e: e != null) (map patchError (lib.filter isPatchName allPatches));
  fuzzyPatches = lib.filter (p: isPatchName p && patchError p == null && dwlPatches.isFuzzy channel p) allPatches;

  resolved = map (p:
    if isPatchName p
    then dwlPatches.resolve channel p
    else {
      src = p;
      pkgConfig = [];
    })
  (lib.filter (p: !(isPatchName p) || patchError p == null) allPatches);

  readable = p: lib.all (c: !(c ? outputs)) (lib.attrValues (builtins.getContext (toString p)));
  patchSources = map (r: r.src) resolved;
  canInspect = lib.all readable patchSources;
  tokens = lib.genAttrs (lib.filter (t: lib.isString t && t != "") (builtins.split "[^A-Za-z0-9_]+" (lib.concatMapStrings builtins.readFile (["${src}/config.def.h" "${src}/dwl.c"] ++ patchSources)))) (_: true);
  unknown = names: lib.optionals canInspect (lib.filter (n: !(tokens ? ${n})) names);

  configErrors =
    patchErrors
    ++ lib.optionals (configH == null) (
      configLib.errors declarative
      ++ map (n: "dwl setting '${n}' doesn't exist in config.def.h, even with your patches applied") (unknown (lib.attrNames settings ++ lib.optional (axes != {}) "axes"))
      ++ map (n: "dwl function '${n}' doesn't exist, check the spelling or add the patch that provides it") (unknown (configLib.functions declarative))
    );

  pkgConfigPackages = with pkgs; {
    fcft = [fcft tllist];
    "pixman-1" = [pixman];
    "dbus-1" = [dbus];
    libevdev = [libevdev];
    libudev = [udev];
    libdrm = [libdrm];
    cairo = [cairo];
    pango = [pango];
    pangocairo = [pango cairo];
    json-c = [json_c];
  };
  patchInputs = lib.concatMap (name:
    pkgConfigPackages.${name} or (lib.warn "dwl: no nixpkgs mapping for pkg-config '${name}', add it via extraBuildInputs" []))
  (lib.unique (lib.concatMap (r: r.pkgConfig) resolved));

  wlrootsMinor = lib.head (builtins.match ".*wlroots-0\\.([0-9]+).*" (builtins.readFile "${src}/config.mk"));
  wlroots' =
    if wlrootsPackage != null
    then wlrootsPackage
    else pkgs."wlroots_0_${wlrootsMinor}" or (throw "dwl: nixpkgs has no wlroots_0_${wlrootsMinor} yet; pass `wlrootsPackage` explicitly");

  configFile =
    if builtins.isPath configH || lib.isDerivation configH
    then configH
    else writeText "config.h" configH;
in
  stdenv.mkDerivation {
    pname = "dwl";
    inherit src version;

    patches = lib.warnIf (fuzzyPatches != []) "dwl: ${lib.concatStringsSep ", " fuzzyPatches} only apply to dwl ${channel} with fuzz, check that they behave as expected" (map (r: r.src) resolved);

    nativeBuildInputs = [installShellFiles pkg-config wayland-scanner];

    buildInputs =
      [libinput libxcb libxkbcommon pixman wayland wayland-protocols wlroots']
      ++ lib.optionals enableXWayland [libx11 libxcb-wm xwayland]
      ++ patchInputs
      ++ extraBuildInputs;

    outputs = ["out" "man"];

    postPatch = lib.throwIf (configErrors != []) (lib.concatStringsSep "\n" configErrors) (
      if configH != null
      then "cp ${configFile} config.h"
      else lib.optionalString (!configLib.isEmpty declarative) "awk -v dir=${editsDir} -f ${./apply-config.awk} config.def.h > config.h"
    );

    makeFlags =
      [
        "PKG_CONFIG=${stdenv.cc.targetPrefix}pkg-config"
        "WAYLAND_SCANNER=wayland-scanner"
        "PREFIX=$(out)"
        "MANDIR=$(man)/share/man"
        "VERSION=${version}"
      ]
      ++ lib.optionals enableXWayland [
        ''XWAYLAND="-DXWAYLAND"''
        ''XLIBS="xcb xcb-icccm"''
      ];

    postInstall = ''
      install -Dm644 config.def.h $out/share/dwl/config.def.h
      install -Dm644 config.h $out/share/dwl/config.h
    '';

    strictDeps = true;
    __structuredAttrs = true;

    passthru = {
      providedSessions = ["dwl"];
      inherit configErrors;
    };

    meta = {
      homepage = "https://codeberg.org/dwl/dwl";
      description = "Dynamic window manager for Wayland";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
      mainProgram = "dwl";
    };
  }
