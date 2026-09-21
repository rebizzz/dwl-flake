# Progress - Survey Upstream
Last visited: 2026-09-21T19:16:40Z

- [x] Initialized DISPATCH and BRIEFING
- [x] Investigate compare-upstream
  - [x] Script examined: `nix/compare-upstream.sh`
  - [x] Executed `nix run .#compare-upstream`:
    - Result: Exited 1 (133/142 patches identical, 9 failed)
    - All 9 failures are on `stable` channel: `bar`, `bar-awesomebar`, `bar-notitle`, `barborder`, `barcolors`, `barconfig`, `barpadding`, `bartruecenteredtitle`, `hide_vacant_tags`.
    - Diff in all 9: Extra `#ifndef TAGCOUNT\n#define TAGCOUNT 31\n#endif` injected into dwl.c by `nix/apply-patches.sh:74-76`
- [x] Investigate Alejandra formatting
  - [x] `nix fmt -- --check .` passed (18 files checked, 0 errors)
- [/] Investigate `nix flake check -L`
  - [x] Evaluated all checks (42 checks)
  - [/] Building checks (running in task-93)
- [/] Investigate NixOS module parity against upstream Nixpkgs (`nixos/modules/programs/wayland/dwl.nix`)
  - [x] Upstream Nixpkgs dwl module inspected at `/nix/store/mkp6xi3vnvrllpmc17337m6sci9chm5l-source/nixos/modules/programs/wayland/dwl.nix`
  - [x] Flake NixOS module inspected (`nix/nixos-module.nix`, `nix/options.nix`, `nix/typed.nix`)
  - [/] Cataloging differences, option specifications, and edge cases
