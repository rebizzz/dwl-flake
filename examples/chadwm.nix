# A chadwm look: floating bar with colored status blocks, catppuccin colors,
# 10px gaps, icon tags and extra layouts. Needs a nerd font and Iosevka.
{
  config,
  pkgs,
  ...
}: let
  inherit (config.lib.dwl) c;
in {
  programs.dwl = {
    enable = true;
    channel = "stable";
    modKey = "Super";

    patches = [
      "bar"
      "barpadding"
      "barcolors"
      "vanitygaps"
      "gaplessgrid"
      "movestack"
      "attachbottom"
      "decklayout"
      "centeredmaster"
    ];

    layouts = [
      {
        symbol = "[]=";
        arrange = "tile";
      }
      {
        symbol = "[M]";
        arrange = "monocle";
      }
      {
        symbol = "H[]";
        arrange = "deck";
      }
      {
        symbol = ":::";
        arrange = "gaplessgrid";
      }
      {
        symbol = "|M|";
        arrange = "centeredmaster";
      }
      {symbol = "><>";}
    ];

    appearance.borderWidth = 3;
    monitors = [{mfact = 0.5;}];

    settings = {
      rootcolor = "#1e1d2d";
      fonts = ["Iosevka:weight=medium:size=12" "JetBrainsMono Nerd Font Mono:size=19"];
      tags = ["" "" "" "" ""];
      gappih = 10;
      gappiv = 10;
      gappoh = 10;
      gappov = 10;
      vertpad = 10;
      sidepad = 10;
      colors = c ''
        {
          [SchemeNorm] = { 0x585767ff, 0x1e1d2dff, 0x282737ff },
          [SchemeSel]  = { 0x282737ff, 0x96cdfbff, 0x96cdfbff },
          [SchemeUrg]  = { 0x1e1d2dff, 0xf28fadff, 0xf28fadff },
        }'';
    };

    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+d".spawn = "rofi -show drun";
      "Mod+q" = "killclient";
      "Mod+t".setlayout = 0;
      "Mod+m".setlayout = 1;
      "Mod+e".setlayout = 2;
      "Mod+g".setlayout = 3;
      "Mod+c".setlayout = 4;
      "Mod+Shift+j".movestack = 1;
      "Mod+Shift+k".movestack = -1;
      "Mod+Ctrl+t" = "togglegaps";
      "Mod+Ctrl+i".incgaps = 1;
      "Mod+Ctrl+d".incgaps = -1;
    };

    statusCommand = ''
      block() {
        printf '^fg(1e1d2d)^bg(%s) %s ^fg(d9e0ee)^bg(282737) %s ^bg()^fg()' "$1" "$2" "$3"
      }
      while true; do
        read -r load _ < /proc/loadavg
        printf '%s %s\n' "$(block abe9b3 CPU "$load")" "$(block 96cdfb 󱑆 "$(date +%H:%M)")"
        sleep 1
      done
    '';
  };

  fonts.packages = [pkgs.iosevka pkgs.nerd-fonts.jetbrains-mono];
  environment.systemPackages = [pkgs.foot pkgs.rofi];
}
