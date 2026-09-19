# A normal daily setup: Super as the main key, your own apps,
# window rules, colors and input settings.
{pkgs, ...}: {
  programs.dwl = {
    extraPackages = with pkgs; [foot fuzzel waybar mako grim slurp wl-clipboard];

    enable = true;
    modKey = "Super";

    autostart = ["waybar" "mako"];

    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+d".spawn = "fuzzel";
      "Mod+q" = "killclient";
      "Mod+f" = "togglefullscreen";
      "Mod+Shift+e" = "quit";
      "Print".spawn = "grim -g \"$(slurp)\" - | wl-copy";
      "XF86AudioRaiseVolume".spawn = "wpctl set-volume @DEFAULT_SINK@ 5%+";
      "XF86AudioLowerVolume".spawn = "wpctl set-volume @DEFAULT_SINK@ 5%-";
    };

    rules = [
      {
        id = "firefox";
        tags = [2];
      }
      {
        id = "mpv";
        floating = true;
      }
    ];

    monitors = [
      {
        name = "eDP-1";
        scale = 1.5;
      }
    ];

    settings = {
      borderpx = 2;
      focuscolor = "#89b4fa";
      bordercolor = "#45475a";
      repeat_rate = 50;
      repeat_delay = 300;
      natural_scrolling = true;
      xkb_rules.options = "caps:escape";
    };
  };
}
