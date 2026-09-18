{
  inputs,
  pkgs,
  ...
}: {
  programs.dwl = {
    enable = true;
    channel = "stable";
    patches = [
      "attachbottom"
      "bar"
      ./patches/thick-borders.patch
      inputs.dwl-flake.variants.autostart."autostart_0.8.patch"
    ];
    extraBuildInputs = [pkgs.libdrm];
    settings.fonts = ["monospace:size=10"];
  };
}
