{
  pkgs,
  dwl-flake,
}:
dwl-flake.packages.${pkgs.stdenv.hostPlatform.system}.dwl.override {
  modKey = "Super";
  patches = ["attachbottom"];
  keybinds."Mod+Return".spawn = "foot";
  settings.borderpx = 2;
}
