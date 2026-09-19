# Examples

Each file is a NixOS module. Pick the one closest to what you want and import it, or copy what you need into your own config.

| example | for when you want to |
| --- | --- |
| [1-minimal.nix](1-minimal.nix) | try dwl with its defaults |
| [2-everyday.nix](2-everyday.nix) | set up your keys, apps, rules and colors |
| [3-patches.nix](3-patches.nix) | add patches |
| [4-home-manager.nix](4-home-manager.nix) | keep the config in Home Manager |
| [5-own-config-h](5-own-config-h) | write your own `config.h` in C |
| [6-chadwm.nix](6-chadwm.nix) | get the chadwm look: floating bar, colored status blocks, gaps, icon tags |

Every option is listed in [docs.md](../docs.md).

## Adding the flake

In your `flake.nix`:

```nix
inputs.dwl-flake = {
  url = "github:rebizzz/dwl-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then import the module in your NixOS config, next to the example:

```nix
imports = [
  inputs.dwl-flake.nixosModules.default
  ./2-everyday.nix
];
```

Every example is built in CI, so they always work with the current flake.
