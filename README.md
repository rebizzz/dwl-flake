# dwl-flake

[![check](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml)
[![update](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml)

Nix flake for [dwl](https://codeberg.org/dwl/dwl) and [dwl-patches](https://codeberg.org/dwl/dwl-patches).

- `dwl` builds dwl `main`. `dwl-stable` builds the latest release.
- Patches from dwl-patches can be added by name. Each one is tested against both builds.
- dwl can be configured from Nix. Mistakes are caught before anything builds.
- NixOS, Home Manager and hjem modules, with Stylix support.

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

All options, and the keybind actions dwl provides, are listed in [docs.md](docs.md). The main ones:

| option | description |
| --- | --- |
| `channel` | `"main"` (default) or `"stable"` |
| `patches` | patch names from dwl-patches, paths, or `fetchpatch` results |
| `modKey` | what `Mod` means: `Super`, `Alt`, `Ctrl` or `Shift` |
| `keybinds` | `"Mod+key" = function` or `{ function = arg; }` |
| `buttons` | mouse bindings, e.g. `"Mod+left".moveresize = "move"` |
| `axes` | scroll wheel bindings (main only) |
| `rules` | window rules |
| `monitors` | monitor rules |
| `appearance` | focus behavior, border width, colors |
| `input.keyboard` | xkb layout and options, key repeat |
| `input.touchpad` | tap, scrolling, acceleration and the rest of libinput |
| `layouts`, `tagCount`, `logLevel` | layouts, number of tags, log level |
| `autostart` | commands to start with dwl |
| `statusCommand` | a script whose output becomes the bar status (bar patch) |
| `environment` | environment variables for dwl and its children |
| `settings` | any variable from `config.def.h`, including ones added by patches |
| `configH` | use your own `config.h` instead |
| `finalConfig` | read-only path to the generated `config.h` |

The [examples](examples) go from a minimal setup to patches, Home Manager, your own `config.h` and a full [chadwm](https://github.com/siduck/chadwm)-style setup.

## Patches

A patch name is resolved to the file that applies to your channel, and the libraries it needs are added to the build. To list what applies:

```sh
nix eval github:rebizzz/dwl-flake#lib.compatible.main
nix eval github:rebizzz/dwl-flake#lib.compatible.stable
```

- `stable` supports more patches than `main`.
- Every patch is built, not just applied. If a patch has several versions, the one that builds is used, and patches that don't build are refused.
- Pick a specific version with `"name:file"`, e.g. `"btrtile:btrtile-v0.8.patch"`.
- Patches that build on another one, like `barpadding` on `bar`, add it for you.
- Two patches that only clash in `config.def.h`, like `bar` and `vanitygaps`, still work together. A clash in code stops the build and names the patch.
- The build warns about patches that need fuzz to apply, because fuzz can put a change in the wrong place.

The patches are also exposed directly, for use with any dwl package:

```nix
pkgs.dwl.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ (with inputs.dwl-flake.lib.patches.stable; [ pertag autostart ]);
})
```

## Updates

A GitHub Action checks codeberg every hour. When dwl, dwl-patches, nixpkgs or the latest dwl release changes, it updates `flake.lock` and regenerates the patch index and `docs.md`. It then opens a pull request with the lock changes in the description.

The pull request merges itself once every check passes: all builds, the examples, the config checks and a VM that boots dwl. If anything fails, it stays open and `main` doesn't change.

The automated pull requests are labeled `automated`. To see only the ones from people, filter with [`is:pr -label:automated`](https://github.com/rebizzz/dwl-flake/pulls?q=is%3Apr+-label%3Aautomated).

In your own config, `nix flake update dwl-flake` gets the latest version that passed.

## License

GPL-3.0, same as dwl.
