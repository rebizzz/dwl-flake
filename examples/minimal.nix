# The smallest setup: dwl with its default config.
# Log in, then press Alt+Shift+Return for a terminal (foot).
{pkgs, ...}: {
  programs.dwl.enable = true;

  environment.systemPackages = [pkgs.foot];
}
