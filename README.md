# dwl-flake

[![check](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/check.yml)
[![update](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml/badge.svg)](https://github.com/rebizzz/dwl-flake/actions/workflows/update.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blueviolet.svg?logo=nixos)](flake.nix)

An advanced, batteries-included Nix flake for [dwl](https://codeberg.org/dwl/dwl) and [dwl-patches](https://codeberg.org/dwl/dwl-patches).

Combines declarative Nix-native configuration with automated C header synthesis, automated patch dependency resolution, multi-channel support, live QEMU VM integration testing, and universal module support for NixOS, Home Manager, Hjem, and Stylix.

---

## Features

- ⚡ **Declarative C Header Synthesis:** Configure dwl directly from Nix attrsets without writing C code. Synthesizes typesafe `#define`s, structs, layouts, monitor rules, window rules, and key/mouse bindings with early evaluation-time error checking.
- 🧩 **Automated Patch Matrix:** Apply patches from `dwl-patches` by name (e.g. `"pertag"`, `"vanitygaps"`, `"bar"`). Automatic dependency resolution, variant selection, and conflict prevention.
- 🔄 **Multi-Channel (`main` & `stable`):** Build against dwl git master (`main`) or the latest tagged release (`stable`, currently 0.8), with per-channel patch compatibility verification.
- 🖥️ **Full Desktop & Session Integration:**
  - Standard `dwl-session` wrapper script with environment exports.
  - Wayland session desktop entry (`share/wayland-sessions/dwl.desktop`) for display managers (GDM, SDDM, greetd).
  - `dwl-session.target` systemd user service synchronization.
  - Polkit agent (`polkitAgent.enable`) and secret management (`keyring.enable`).
  - XDG Desktop Portal configuration (`wlr`, `gtk`).
  - Out-of-the-box PAM screen locker authentication for `swaylock`.
  - GTK/dconf integration (`programs.dconf.enable`).
- 🏠 **Universal Modules:**
  - **NixOS Module:** Full system integration, session discovery, and per-user custom builds (`useHomeManagerBuild`).
  - **Home Manager Module:** First-class user configuration for both NixOS and standalone Linux distributions (Arch, Fedora, Ubuntu, etc.).
  - **Hjem Module:** Native support for the lightweight [hjem](https://github.com/feel-co/hjem) home manager.
  - **Stylix Support:** Automatic color palette, wallpaper, and font synchronization across your desktop.
- 🧪 **Live QEMU VM Integration Testing:** Comprehensive end-to-end VM tests verifying display initialization, systemd user session targets, XDG portals, PAM screen locking, and client lifecycle.
- 🤖 **Zero-Maintenance Automated CI/CD:** Scheduled upstream tracking on GitHub Actions that tests every patch against both channels, updates lockfiles, and auto-merges PRs.
- 🛠️ **Developer Friendly:** Bundled `justfile` recipes and a feature-complete `nix develop` shell.

---

## Quickstart

### 1. Add Flake Input

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dwl-flake = {
      url = "github:rebizzz/dwl-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

---

### 2. NixOS Configuration

Import the NixOS module:

```nix
# configuration.nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.dwl-flake.nixosModules.default ];

  programs.dwl = {
    enable = true;
    channel = "main"; # or "stable"
    modKey = "Super";
    patches = [ "pertag" ];
    autostart = [ "waybar" ];
    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+q" = "killclient";
      "Mod+l".spawn = "swaylock";
    };
    settings.borderpx = 2;
  };

  # Optional: use greetd with dwl
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.greetd}/bin/agreety --cmd dwl-session";
  };
}
```

This sets up:
- The `dwl-session` wrapper script in `/etc/xdg/dwl-session` and `PATH`.
- Display manager session discovery via `/share/wayland-sessions/dwl.desktop`.
- `dwl-session.target` systemd user target.
- Polkit authentication agent and GNOME Keyring.
- `swaylock` PAM service configuration.
- XDG portals (`xdg-desktop-portal-wlr` and `gtk`).

---

### 3. Home Manager Configuration

#### On NixOS (Shared or Per-User Build)

When importing `inputs.dwl-flake.nixosModules.default`, the Home Manager module is automatically shared. Set `useHomeManagerBuild = true` on NixOS so each user can compile their own personalized dwl build:

```nix
# NixOS configuration.nix
programs.dwl = {
  enable = true;
  useHomeManagerBuild = true; # Launches each user's HM build
};

# Home Manager home.nix
programs.dwl = {
  enable = true;
  patches = [ "pertag" ];
  keybinds = {
    "Mod+Return".spawn = "foot";
    "Mod+q" = "killclient";
  };
};
```

#### Standalone Home Manager (Non-NixOS Linux)

On non-NixOS distributions (e.g. Arch, Debian, Fedora), the Home Manager module provides the full session stack:

```nix
# home.nix
{ inputs, ... }: {
  imports = [ inputs.dwl-flake.homeModules.default ];

  programs.dwl = {
    enable = true;
    modKey = "Super";
    patches = [ "pertag" ];
    keybinds."Mod+Return".spawn = "foot";
  };
}
```

This installs:
- The `dwl` binary and `dwl-session` launcher.
- `~/.local/share/wayland-sessions/dwl.desktop` (so GDM, SDDM, or greetd can find dwl).
- `systemd.user.targets.dwl-session` for managing user daemons.

---

### 4. Hjem Configuration

For users of the lightweight [hjem](https://github.com/feel-co/hjem) home manager:

```nix
{ inputs, ... }: {
  imports = [ inputs.dwl-flake.hjemModules.default ];

  programs.dwl = {
    enable = true;
    modKey = "Super";
    patches = [ "pertag" ];
  };
}
```

---

### 5. Stylix Theming

With [Stylix](https://github.com/danth/stylix) enabled, dwl's colors and fonts synchronize with your global theme automatically:

```nix
{ inputs, ... }: {
  imports = [
    inputs.dwl-flake.nixosModules.default
    # or inputs.dwl-flake.homeModules.default
  ];

  # Stylix handles colors, fonts, and borders automatically
  stylix.enable = true;
}
```

To disable dwl styling while keeping Stylix active elsewhere:
```nix
stylix.targets.dwl.enable = false;
```

---

### 6. Package Only / Standalone Build

Override patches and settings directly in your flake:

```nix
inputs.dwl-flake.packages.${system}.dwl.override {
  channel = "main";
  patches = [ "pertag" ./my-custom-fix.patch ];
  settings.borderpx = 3;
}
```

Or run directly without installing:

```sh
# Run dwl main
nix run github:rebizzz/dwl-flake

# Run dwl stable
nix run github:rebizzz/dwl-flake#dwl-stable
```

---

### 7. Overlays

The flake provides drop-in overlays:

```nix
nixpkgs.overlays = [
  # Provides pkgs.dwl, pkgs.dwl-git, pkgs.dwl-stable, pkgs.dwl-stable-git
  inputs.dwl-flake.overlays.default

  # Or target a specific channel directly:
  # inputs.dwl-flake.overlays.dwl         # pkgs.dwl = dwl main
  # inputs.dwl-flake.overlays.dwl-stable  # pkgs.dwl = dwl stable
];
```

---

## Options Overview

All options are documented in detail in [docs.md](docs.md). Key configuration options:

| Option | Type | Description |
| :--- | :--- | :--- |
| `programs.dwl.enable` | `boolean` | Enable dwl and its session integration. |
| `programs.dwl.channel` | `"main"` or `"stable"` | Build dwl git master (`"main"`) or latest release (`"stable"`). |
| `programs.dwl.package` | `package` | The dwl package to use (defaults to declarative build). |
| `programs.dwl.patches` | `listOf (oneOf [str path package])` | Patches to apply from `dwl-patches` by name or local file paths. |
| `programs.dwl.modKey` | `nullOr str` | What `Mod` represents: `"Super"`, `"Alt"`, `"Ctrl"`, or `"Shift"`. |
| `programs.dwl.keybinds` | `attrsOf (either str (attrsOf anything))` | Keybindings as `"Modifiers+keysym" = action`. |
| `programs.dwl.buttons` | `attrsOf (either str (attrsOf anything))` | Mouse bindings, e.g. `"Mod+left".moveresize = "move"`. |
| `programs.dwl.axes` | `attrsOf (either str (attrsOf anything))` | Scroll wheel bindings (`main` only). |
| `programs.dwl.rules` | `listOf rule` | Window rules (app_id, title, tags, floating, monitor). |
| `programs.dwl.monitors` | `listOf monitor` | Output monitor rules (name, scale, layout, transform, position). |
| `programs.dwl.autostart` | `listOf str` | Commands started with dwl (automatically includes `autostart` patch). |
| `programs.dwl.startupCommand` | `lines` | Shell commands run once dwl is up, with Wayland environment set. |
| `programs.dwl.extraSessionCommands` | `lines` | Shell commands run before dwl starts. |
| `programs.dwl.extraOptions` | `listOf str` | Command-line arguments passed to dwl (e.g. `["-d"]`). |
| `programs.dwl.statusCommand` | `nullOr str` | Shell command whose output lines become the bar status text (bar patch). |
| `programs.dwl.extraPackages` | `listOf package` | Packages installed alongside dwl (default: `foot`, `wmenu`). |
| `programs.dwl.environment` | `attrsOf str` | Environment variables set for dwl and all child processes. |
| `programs.dwl.settings` | `attrsOf anything` | Variables or defines from `config.def.h`, including ones added by patches. |
| `programs.dwl.configH` | `nullOr (either path lines)` | Path or string of custom `config.h` (bypasses declarative settings). |
| `programs.dwl.finalConfig` | `readOnly str` | Read-only path to the generated `config.h` in the Nix store. |
| `programs.dwl.useHomeManagerBuild` | `boolean` *(NixOS only)* | Launch each user's Home Manager build. |
| `programs.dwl.polkitAgent.enable` | `boolean` *(NixOS only)* | Polkit authentication agent in the dwl session (default: `true`). |
| `programs.dwl.keyring.enable` | `boolean` *(NixOS only)* | GNOME Keyring for secret storage (default: `true`). |

Check the [examples](examples) directory for configurations ranging from minimal setups to patches, custom `config.h`, and a Siduck [chadwm](https://github.com/siduck/chadwm)-style desktop.

---

## Patches System

Patches are fetched directly from [dwl-patches](https://codeberg.org/dwl/dwl-patches) and verified across channels:

```sh
# List all patches that apply cleanly to 'main'
nix eval github:rebizzz/dwl-flake#lib.compatible.main

# List all patches that apply cleanly to 'stable'
nix eval github:rebizzz/dwl-flake#lib.compatible.stable
```

### Dependency Resolution & Safety
- **Automatic Dependencies:** Requesting `barpadding` automatically pulls in `bar`.
- **Shared Code Coordination:** Patches touching overlapping lines in `config.def.h` (e.g. `bar` and `vanitygaps`) are reconciled automatically.
- **Specific Variants:** Use `"name:file"` syntax to select a specific patch version, e.g. `"btrtile:btrtile-v0.8.patch"`.
- **Compile-Time Safety:** Incompatible or broken patch combinations are rejected during evaluation with helpful error messages.

---

## Developer Workflows

A `justfile` is included for rapid development:

```sh
# List all recipes
just

# Format code
just fmt

# Run all checks (eval, VM tests, patch verification)
just check

# Run the live NixOS QEMU VM test driver interactively
just test-vm

# Update upstream dwl, patches, and lockfile
just update

# Rebuild documentation
just update-docs
```

Or enter the development shell:

```sh
nix develop
```

---

## License

GPL-3.0, matching upstream [dwl](https://codeberg.org/dwl/dwl).
