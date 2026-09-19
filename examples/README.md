# Examples

Each file is a NixOS module. Pick the one closest to what you want and import it, or copy what you need into your own config.

| example | for when you want to |
| --- | --- |
| [minimal.nix](minimal.nix) | try dwl with its defaults |
| [everyday.nix](everyday.nix) | set up your keys, apps, rules and colors |
| [patches.nix](patches.nix) | add patches |
| [home-manager.nix](home-manager.nix) | keep the config in Home Manager |
| [config-h](config-h) | write your own `config.h` in C |
| [chadwm.nix](chadwm.nix) | get the chadwm look: floating bar, colored status blocks, gaps, icon tags |

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
  ./everyday.nix
];
```

Every example is built in CI, so they always work with the current flake.
