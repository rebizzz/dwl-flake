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
  python3 ? pkgs.python3,
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

  isPatchName = p: builtins.isString p && !lib.hasPrefix "/" p;

  withAutostart = patches ++ lib.optional (autostart != [] && !lib.elem "autostart" patches) "autostart";
  requiredBy = p:
    if isPatchName p && dwlPatches != null
    then dwlPatches.requiredBy channel p
    else null;
  withDependencies = lib.unique (lib.concatMap (p: lib.optional (requiredBy p != null) (requiredBy p) ++ [p]) withAutostart);

  # The engine applies patches in its own phase order; this only has to record
  # a patch after the one it depends on.
  mustPrecede = a: b: let
    nameA =
      if isPatchName a
      then (dwlPatches.parse a).name
      else a;
  in
    requiredBy b == nameA;

  sortedPatchesResult = lib.toposort mustPrecede withDependencies;
  allPatches =
    if sortedPatchesResult ? result
    then sortedPatchesResult.result
    else withDependencies;

  patchError = p: let
    spec = dwlPatches.parse p;
    entry = dwlPatches.index.${spec.name} or null;
    other =
      if channel == "main"
      then "stable"
      else "main";
  in
    if dwlPatches == null
    then "dwl patch '${p}' was given by name, but no dwl-patches index is available"
    else if entry == null
    then "dwl patch '${spec.name}' doesn't exist in dwl-patches"
    else if spec.file != null && !(entry.files ? ${spec.file})
    then "dwl patch '${spec.name}' has no file '${spec.file}' (${lib.concatStringsSep ", " (lib.attrNames entry.files)})"
    else if spec.file != null && dwlPatches.fileFor channel p == null
    then "dwl patch file '${p}' doesn't apply to dwl ${channel}"
    else if dwlPatches.isBroken channel p
    then "dwl patch '${p}' applies to dwl ${channel} but doesn't build${lib.optionalString (dwlPatches.fileFor other p != null) ", but it works with channel = \"${other}\""}"
    else if dwlPatches.fileFor channel p == null
    then "dwl patch '${p}' has no version that applies to dwl ${channel} (${lib.concatStringsSep ", " (lib.attrNames entry.files)})${lib.optionalString (dwlPatches.fileFor other p != null) ", but it works with channel = \"${other}\""}"
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

  # A directory named `engine` so `python3 -m engine` finds it on PYTHONPATH.
  patchEngine = pkgs.runCommand "dwl-patch-engine" {} ''
    mkdir -p $out/engine
    cp ${./engine}/*.py $out/engine/
  '';
in
  stdenv.mkDerivation {
    pname = "dwl";
    inherit src version;

    patches = lib.warnIf (fuzzyPatches != []) "dwl: these patches need fuzz to apply to dwl ${channel}, check that they behave as expected: ${lib.concatStringsSep ", " fuzzyPatches}" (map (r: r.src) resolved);

    nativeBuildInputs = [
      installShellFiles
      pkg-config
      wayland-scanner
      python3
    ];

    patchPhase = ''
      runHook prePatch

      if [ ''${#patches[@]} -gt 0 ]; then
        PYTHONPATH=${patchEngine} python3 -m engine \
          --channel "${channel}" \
          --target . \
          "''${patches[@]}"
      fi

      runHook postPatch
    '';

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

    env.NIX_CFLAGS_COMPILE = lib.concatStringsSep " " (
      lib.optional (lib.any (r: lib.elem "libdrm" r.pkgConfig) resolved) "-I${lib.getDev pkgs.libdrm}/include/libdrm"
      ++ lib.optionals (configH == null && (!defaultKeybinds || !defaultButtons || axes != {} || settings ? layouts)) ["-Wno-unused-function" "-Wno-unused-variable"]
    );

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
