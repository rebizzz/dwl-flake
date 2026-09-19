# Keep dwl's config in Home Manager, next to the rest of your user config.
# This goes in your NixOS config. The Home Manager module is added for you.
{
  programs.dwl = {
    enable = true;
    useHomeManagerBuild = true;
  };

  home-manager.users.alice = {
    programs.dwl = {
      enable = true;
      modKey = "Super";
      keybinds."Mod+Return".spawn = "kitty";
      settings.borderpx = 2;
    };
  };
}
