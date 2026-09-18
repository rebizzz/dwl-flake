# dwl-flake

[![update](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml)

Nix flake for [dwl](https://codeberg.org/dwl/dwl) and [dwl-patches](https://codeberg.org/dwl/dwl-patches). Both are pinned straight from codeberg, and a GitHub Action updates them every 6 hours. It only pushes the update if everything builds.

- `dwl` builds dwl `main`. `dwl-stable` builds the latest release.
- Patches from dwl-patches can be added by name. Each one is tested against both builds.
- dwl can be configured from Nix.
- NixOS and Home Manager modules.

## Usage

```nix
{
  inputs.dwl = {
    url = "github:rebizzz/dwl-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### NixOS

```nix
{ inputs, ... }: {
  imports = [ inputs.dwl.nixosModules.default ];

  programs.dwl = {
    enable = true;
    useHomeManagerBuild = true;
  };
}
```

This extends nixpkgs' `programs.dwl`, which sets up the session, systemd target and portals. With `useHomeManagerBuild`, the session starts the dwl built by your Home Manager config.

### Home Manager

```nix
{ inputs, ... }: {
  imports = [ inputs.dwl.homeModules.default ];

  programs.dwl = {
    enable = true;
    modKey = "Super";
    patches = [ "pertag" ];
    autostart = [ "waybar" ];

    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+d".spawn = "fuzzel";
      "Mod+q" = "killclient";
      "Mod+1".view = 1;
      "Mod+Shift+1".tag = 1;
    };

    rules = [
      { id = "firefox"; tags = [ 2 ]; }
      { id = "mpv"; floating = true; }
    ];

    monitors = [
      { name = "eDP-1"; scale = 1.5; }
    ];

    settings = {
      borderpx = 2;
      focuscolor = "#89b4fa";
      natural_scrolling = true;
      xkb_rules = { layout = "us"; options = "caps:escape"; };
    };
  };
}
```

Run `nix flake update` to get the latest dwl and patches.

### Package only

```nix
inputs.dwl.packages.${system}.dwl.override {
  patches = [ "pertag" ./my.patch ];
  settings.borderpx = 2;
}
```

An overlay is also available as `overlays.default`. It adds `pkgs.dwl-git`.

## Options

All of these live under `programs.dwl`, in both modules.

| option | description |
| --- | --- |
| `channel` | `"main"` (default) or `"stable"` |
| `patches` | patch names from dwl-patches, paths, or `fetchpatch` results |
| `modKey` | what `Mod` means: `Super`, `Alt`, `Ctrl` or `Shift` |
| `keybinds` | `"Mod+key" = function` or `{ function = arg; }` |
| `defaultKeybinds` | keep dwl's default binds alongside yours (default `true`) |
| `rules` | window rules: `id`, `title`, `tags`, `floating`, `monitor` |
| `monitors` | monitor rules: `name`, `scale`, `mfact`, `nmaster`, `layout`, `transform`, `x`, `y` |
| `autostart` | commands to start with dwl |
| `settings` | any variable from `config.def.h`, including ones added by patches |
| `extraConfig` | C code added to the top of `config.h` |
| `configH` | use your own `config.h` instead |
| `xwayland` | build with XWayland (default `true`) |
| `extraBuildInputs` | libraries a patch needs that aren't detected |
| `useHomeManagerBuild` | NixOS only |

To see what a setting is called, look in [config.def.h](https://codeberg.org/dwl/dwl/src/branch/main/config.def.h). The generated `config.h` is installed to `share/dwl/config.h`.

## Patches

A patch name is resolved to the file that applies to your channel, and the libraries it needs are added to the build. To list what applies:

```sh
nix eval github:rebizzz/dwl-flake#lib.compatible.main
nix eval github:rebizzz/dwl-flake#lib.compatible.stable
```

More patches support `stable` than `main`.

The flake also exposes the patches directly, for use with any dwl package:

```nix
pkgs.dwl.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ (with inputs.dwl.patches.stable; [ pertag autostart ]);
})
```

## License

GPL-3.0, same as dwl.
