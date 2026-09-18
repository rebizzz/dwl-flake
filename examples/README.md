# Examples

| file | shows |
| --- | --- |
| [flake.nix](flake.nix) | wiring it into a flake: NixOS only, NixOS with Home Manager, standalone Home Manager, and a package |
| [nixos.nix](nixos.nix) | a full config in the NixOS module |
| [home.nix](home.nix) | a config in the Home Manager module |
| [patches.nix](patches.nix) | patches by name, a local patch file and a specific patch variant |
| [config-h.nix](config-h.nix) | using your own [config.h](config.h) instead of the options |
| [package.nix](package.nix) | just the package, with `.override` |

Every file here is evaluated and built in CI, so they always work with the current flake.
