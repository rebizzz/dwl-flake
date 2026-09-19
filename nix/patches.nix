{
  lib,
  src,
}: let
  index = lib.importJSON ./patches.json;
  channels = ["main" "stable"];

  pathOf = name: file: "${src}/patches/${name}/${file}";
  compatibleWith = channel: lib.filterAttrs (_: p: p.default.${channel} != null) index;
in {
  inherit index;

  patches = lib.genAttrs channels (channel: lib.mapAttrs (name: p: pathOf name p.default.${channel}) (compatibleWith channel));

  variants = lib.mapAttrs (name: p: lib.mapAttrs (file: _: pathOf name file) p.files) index;

  requiredBy = channel: name: let
    p = index.${name} or null;
    file =
      if p == null
      then null
      else p.default.${channel};
  in
    if p != null && (p.requires or null) != null && file != null && (p.files.${file}.needsRequired.${channel} or false)
    then p.requires
    else null;

  isFuzzy = channel: name: let
    p = index.${name} or null;
    file =
      if p == null
      then null
      else p.default.${channel};
  in
    file != null && (p.files.${file}.fuzzy.${channel} or false);

  compatible = lib.genAttrs channels (channel: lib.attrNames (compatibleWith channel));

  resolve = channel: name: let
    p = index.${name} or (throw "dwl-patches: no patch named '${name}'");
    file = p.default.${channel};
  in
    if file == null
    then throw "dwl-patches: '${name}' has no variant that applies to dwl ${channel} (${lib.concatStringsSep ", " (lib.attrNames p.files)})"
    else {
      src = pathOf name file;
      inherit (p.files.${file}) pkgConfig;
    };
}
