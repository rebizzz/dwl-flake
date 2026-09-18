{pkgs, ...}: {
  programs.dwl = {
    enable = true;
    modKey = "Super";
    patches = ["pertag" "movestack"];
    autostart = ["waybar" "mako"];

    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+d".spawn = "fuzzel";
      "Mod+q" = "killclient";
      "Mod+Shift+e" = "quit";
      "Mod+f" = "togglefullscreen";
      "Mod+space" = "togglefloating";
      "Mod+j".focusstack = 1;
      "Mod+k".focusstack = -1;
      "Mod+Shift+j".movestack = 1;
      "Mod+Shift+k".movestack = -1;
      "Mod+h".setmfact = -0.05;
      "Mod+l".setmfact = 0.05;
      "Mod+t".setlayout = 0;
      "Mod+m".setlayout = 2;
      "Print".spawn = "grim -g \"$(slurp)\" - | wl-copy";
      "XF86AudioRaiseVolume".spawn = "wpctl set-volume @DEFAULT_SINK@ 5%+";
      "XF86AudioLowerVolume".spawn = "wpctl set-volume @DEFAULT_SINK@ 5%-";
      "XF86AudioMute".spawn = "wpctl set-mute @DEFAULT_SINK@ toggle";
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
      {
        title = "Picture-in-Picture";
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
      rootcolor = "#1e1e2e";
      bordercolor = "#45475a";
      focuscolor = "#89b4fa";
      urgentcolor = "#f38ba8";
      repeat_rate = 50;
      repeat_delay = 300;
      tap_to_click = true;
      natural_scrolling = true;
      xkb_rules = {
        layout = "us";
        options = "caps:escape";
      };
    };
  };

  environment.systemPackages = with pkgs; [foot fuzzel waybar mako grim slurp wl-clipboard];
}
