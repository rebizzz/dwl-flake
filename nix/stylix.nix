{
  config,
  lib,
  ...
}: {
  options.stylix.targets.dwl.enable = config.lib.stylix.mkEnableTarget "dwl" true;

  config = lib.mkIf (config.stylix.enable && config.stylix.targets.dwl.enable) {
    programs.dwl.settings = with config.lib.stylix.colors.withHashtag;
      lib.mapAttrs (_: lib.mkDefault) {
        rootcolor = base00;
        bordercolor = base03;
        focuscolor = base0D;
        urgentcolor = base08;
      };
  };
}
