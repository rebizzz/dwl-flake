{
  programs.dwl = {
    enable = true;
    channel = "stable";
    modKey = "Super";
    patches = ["pertag" "attachbottom"];
    autostart = ["dex --autostart --environment dwl"];
    keybinds = {
      "Mod+Return".spawn = "kitty";
      "Mod+q" = "killclient";
    };
    rules = [
      {
        id = "brave-browser";
        tags = [2];
      }
    ];
    settings = {
      borderpx = 2;
      focuscolor = "#89b4fa";
    };
  };
}
