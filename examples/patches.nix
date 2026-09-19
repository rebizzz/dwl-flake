# Adding patches. Names come from dwl-patches, and their dependencies
# are added for you. Your own .patch files work too.
# See what's available: nix eval github:rebizzz/dwl-flake#lib.compatible.stable
{
  programs.dwl = {
    enable = true;
    channel = "stable";

    patches = [
      "attachbottom"
      "movestack"
      ./thick-borders.patch
    ];

    keybinds = {
      "Mod+Shift+j".movestack = 1;
      "Mod+Shift+k".movestack = -1;
    };
  };
}
