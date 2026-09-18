# dwl-flake

[![check](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml)
[![update](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml)

Nix flake for [dwl](https://codeberg.org/dwl/dwl) and [dwl-patches](https://codeberg.org/dwl/dwl-patches).

- `dwl` builds dwl `main`. `dwl-stable` builds the latest release.
- Patches from dwl-patches can be added by name. Each one is tested against both builds.
- dwl can be configured from Nix. Mistakes are caught before anything builds.
- NixOS, Home Manager and hjem modules, with Stylix support.
- Updates hourly from codeberg. An update only lands after every check passes, including booting dwl in a VM.

## Usage

```nix
{
  inputs.dwl-flake = {
    url = "github:rebizzz/dwl-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### NixOS

```nix
{ inputs, ... }: {
  imports = [ inputs.dwl-flake.nixosModules.default ];

  programs.dwl = {
    enable = true;
    modKey = "Super";
    patches = [ "pertag" ];
    autostart = [ "waybar" ];
    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+q" = "killclient";
    };
    settings.borderpx = 2;
  };
}
```

This sets up the session, portals, polkit agent, gnome-keyring and a `dwl-session.target` for user services. Pick `dwl` in your display manager, or run `dwl-session` from a TTY.

### Home Manager

When the NixOS module is imported, the Home Manager module is added to every user automatically. Set `useHomeManagerBuild` so the session starts the dwl your Home Manager config builds:

```nix
# NixOS
programs.dwl = {
  enable = true;
  useHomeManagerBuild = true;
};

# Home Manager
programs.dwl = {
  enable = true;
  patches = [ "pertag" ];
  keybinds."Mod+Return".spawn = "kitty";
};
```

Standalone Home Manager: import `inputs.dwl-flake.homeModules.default`. hjem: import `inputs.dwl-flake.hjemModules.default`.

### Stylix

With Stylix enabled, dwl's colors follow your theme. Turn it off with `stylix.targets.dwl.enable = false`. On NixOS it's automatic for Home Manager users. Otherwise, import `nixosModules.stylix` or `homeModules.stylix`.

### Package only

```nix
inputs.dwl-flake.packages.${system}.dwl.override {
  patches = [ "pertag" ./my.patch ];
  settings.borderpx = 2;
}
```

`overlays.default` adds `pkgs.dwl-git` and `pkgs.dwl-stable-git`.

## Options

All options are listed in [docs.md](docs.md). The main ones:

| option | description |
| --- | --- |
| `channel` | `"main"` (default) or `"stable"` |
| `patches` | patch names from dwl-patches, paths, or `fetchpatch` results |
| `modKey` | what `Mod` means: `Super`, `Alt`, `Ctrl` or `Shift` |
| `keybinds` | `"Mod+key" = function` or `{ function = arg; }` |
| `rules` | window rules |
| `monitors` | monitor rules |
| `autostart` | commands to start with dwl |
| `settings` | any variable from `config.def.h`, including ones added by patches |
| `configH` | use your own `config.h` instead |

See [examples](examples) for complete configs.

## Patches

A patch name is resolved to the file that applies to your channel, and the libraries it needs are added to the build. To list what applies:

```sh
nix eval github:rebizzz/dwl-flake#lib.compatible.main
nix eval github:rebizzz/dwl-flake#lib.compatible.stable
```

More patches support `stable` than `main`. Patches that apply on their own can still conflict with each other.

The patches are also exposed directly, for use with any dwl package:

```nix
pkgs.dwl.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ (with inputs.dwl-flake.patches.stable; [ pertag autostart ]);
})
```

## License

GPL-3.0, same as dwl.
