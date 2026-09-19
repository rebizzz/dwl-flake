{
  lib,
  src,
}: let
  index = lib.importJSON ./patches.json;
  verified = lib.importJSON ./verified.json;
  channels = ["main" "stable"];

  pathOf = name: file: "${src}/patches/${name}/${file}";

  parse = spec: let
    m = builtins.match "([^:]+):(.+)" spec;
  in
    if m == null
    then {
      name = spec;
      file = null;
    }
    else {
      name = lib.elemAt m 0;
      file = lib.elemAt m 1;
    };

  fileFor = channel: spec: let
    inherit (parse spec) name file;
    p = index.${name} or null;
    override = verified.${channel} or {};
  in
    if p == null
    then null
    else if file != null
    then
      (
        if (p.files.${file}.applies.${channel} or false)
        then file
        else null
      )
    else if override ? ${name}
    then override.${name}
    else p.default.${channel};
  isBroken = channel: spec: let
    inherit (parse spec) name file;
  in
    file == null && (index ? ${name}) && index.${name}.default.${channel} != null && fileFor channel spec == null;

  compatibleWith = channel: lib.filterAttrs (name: _: fileFor channel name != null) index;
in {
  inherit index verified parse fileFor isBroken;

  patches = lib.genAttrs channels (channel: lib.mapAttrs (name: _: pathOf name (fileFor channel name)) (compatibleWith channel));

  variants = lib.mapAttrs (name: p: lib.mapAttrs (file: _: pathOf name file) p.files) index;

  requiredBy = channel: spec: let
    p = index.${(parse spec).name} or null;
    file = fileFor channel spec;
  in
    if file != null && (p.requires or null) != null && (p.files.${file}.needsRequired.${channel} or false)
    then p.requires
    else null;

  isFuzzy = channel: spec: let
    file = fileFor channel spec;
  in
    file != null && (index.${(parse spec).name}.files.${file}.fuzzy.${channel} or false);

  compatible = lib.genAttrs channels (channel: lib.attrNames (compatibleWith channel));

  resolve = channel: spec: let
    inherit (parse spec) name;
    p = index.${name} or (throw "dwl-patches: no patch named '${name}'");
    file = fileFor channel spec;
  in
    if file == null
    then throw "dwl-patches: '${name}' has no variant that works with dwl ${channel} (${lib.concatStringsSep ", " (lib.attrNames p.files)})"
    else {
      src = pathOf name file;
      inherit (p.files.${file}) pkgConfig;
    };
}
