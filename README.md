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

You can try it right now with `nix run github:rebizzz/dwl-flake`, or `nix run github:rebizzz/dwl-flake#dwl-stable` for the latest release.

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

This sets up the session, portals, polkit agent, gnome-keyring, swaylock PAM, dconf and a `dwl-session.target` for user services. Pick `dwl` in your display manager, or run `dwl-session` from a TTY.

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

The Home Manager module also works standalone on non-NixOS systems. It installs `dwl-session`, a `.desktop` file for display managers, and a `dwl-session.target` for user daemons.

### Hjem

```nix
{ inputs, ... }: {
  imports = [ inputs.dwl-flake.hjemModules.default ];

  programs.dwl = {
    enable = true;
    modKey = "Super";
  };
}
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

### Overlays

`overlays.default` adds `pkgs.dwl`, `pkgs.dwl-git`, `pkgs.dwl-stable` and `pkgs.dwl-stable-git`. There's also `overlays.dwl-stable` if you want `pkgs.dwl` to be the latest release.

## Options

All options and keybind actions are documented in [`docs.md`](docs.md). The highlights: `channel`, `patches`, `modKey`, `keybinds`, `buttons`, `rules`, `monitors`, `autostart`, `appearance`, `input`, `settings`, `configH`. The NixOS module also has `useHomeManagerBuild`, `polkitAgent` and `keyring`.

The [examples](examples) go from a minimal setup to patches, Home Manager, your own `config.h` and a full [chadwm](https://github.com/siduck/chadwm)-style setup.

## Patches

All patches and their compatibility are documented in [`patches.md`](patches.md).

A patch name is resolved to the file that applies to your channel, and the libraries it needs are added to the build. To list what applies:

```sh
nix eval github:rebizzz/dwl-flake#lib.compatible.main
nix eval github:rebizzz/dwl-flake#lib.compatible.stable
```

Most patches target the latest release, so `stable` works with more of them than `main`. Every patch is actually built, and ones that don't compile are refused. If you need a specific version of a patch, write `"name:file"`, like `"btrtile:btrtile-v0.8.patch"`.

You don't need to worry about patch order or dependencies much. `barpadding` needs `bar`, so asking for `barpadding` adds `bar` for you. Patches that only touch the same lines in `config.def.h`, like `bar` and `vanitygaps`, still work together. If two patches really conflict, the build stops and tells you which one.

The patches are also exposed directly, for use with any dwl package:

```nix
pkgs.dwl.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ (with inputs.dwl-flake.lib.patches.stable; [ pertag autostart ]);
})
```

## Development

Enter the dev shell with `nix develop`. A `justfile` is included:

```sh
just fmt             # format all nix files
just check           # run all checks
just eval            # eval-only check across all systems
just test-vm         # boot the NixOS VM integration test
just update          # update dwl, patches, and lockfile
just update-docs     # regenerate docs.md
just verify-patches  # verify all default patches apply
just compare-upstream # compare with upstream nixpkgs module
```

## Updates

A GitHub Action checks codeberg every hour. When dwl, dwl-patches, nixpkgs or the latest dwl release changes, it updates `flake.lock` and regenerates the patch index and `docs.md`. It then opens a pull request with the lock changes in the description.

The pull request merges itself once every check passes: all builds, the examples, the config checks and a VM that boots dwl. If anything fails, it stays open and `main` doesn't change.

The automated pull requests are labeled `automated`. To see only the ones from people, filter with [`is:pr -label:automated`](https://github.com/rebizzz/dwl-flake/pulls?q=is%3Apr+-label%3Aautomated).

In your own config, `nix flake update dwl-flake` gets the latest version that passed.

## License

GPL-3.0, same as dwl.
