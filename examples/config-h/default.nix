# Prefer writing C? Point dwl at your own config.h.
# Start from dwl's defaults: nix build github:rebizzz/dwl-flake && cp result/share/dwl/config.def.h config.h
{
  programs.dwl = {
    enable = true;
    configH = ./config.h;
  };
}
