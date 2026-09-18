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
  linkFarm,
}: let
  configLib = import ./config.nix {inherit lib;};
  declarative = {inherit settings keybinds defaultKeybinds modKey rules monitors autostart extraConfig;};
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

  allPatches = patches ++ lib.optional (autostart != [] && !lib.elem "autostart" patches) "autostart";

  isPatchName = p: builtins.isString p && !lib.hasPrefix "/" p;

  resolved = map (p:
    if isPatchName p
    then
      if dwlPatches == null
      then throw "dwl: patch '${p}' given by name but no dwl-patches index is available"
      else dwlPatches.resolve channel p
    else {
      src = p;
      pkgConfig = [];
    })
  allPatches;

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

    patches = map (r: r.src) resolved;

    nativeBuildInputs = [installShellFiles pkg-config wayland-scanner];

    buildInputs =
      [libinput libxcb libxkbcommon pixman wayland wayland-protocols wlroots']
      ++ lib.optionals enableXWayland [libx11 libxcb-wm xwayland]
      ++ patchInputs
      ++ extraBuildInputs;

    outputs = ["out" "man"];

    postPatch =
      if configH != null
      then "cp ${configFile} config.h"
      else lib.optionalString (!configLib.isEmpty declarative) "awk -v dir=${editsDir} -f ${./apply-config.awk} config.def.h > config.h";

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

    passthru.providedSessions = ["dwl"];

    meta = {
      homepage = "https://codeberg.org/dwl/dwl";
      description = "Dynamic window manager for Wayland";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
      mainProgram = "dwl";
    };
  }
