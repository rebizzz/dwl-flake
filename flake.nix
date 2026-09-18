{
  description = "dwl and dwl-patches for Nix: main and stable builds, patches by name, declarative config, NixOS and Home Manager modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    dwl-src = {
      url = "git+https://codeberg.org/dwl/dwl?shallow=1";
      flake = false;
    };
    dwl-stable-src = {
      url = "git+https://codeberg.org/dwl/dwl?ref=refs/tags/v0.8&shallow=1";
      flake = false;
    };
    dwl-patches-src = {
      url = "git+https://codeberg.org/dwl/dwl-patches?shallow=1";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    dwl-src,
    dwl-stable-src,
    dwl-patches-src,
  }: let
    inherit (nixpkgs) lib;

    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

    dwlPatches = import ./nix/patches.nix {
      inherit lib;
      src = dwl-patches-src;
    };

    configVersion = src: lib.head (builtins.match ".*_VERSION[[:space:]]*=[[:space:]]*([^[:space:]]+).*" (builtins.readFile "${src}/config.mk"));
    date = d: "${lib.substring 0 4 d}-${lib.substring 4 2 d}-${lib.substring 6 2 d}";

    channels = {
      main = {
        src = dwl-src;
        version = "${configVersion dwl-src}-unstable-${date dwl-src.lastModifiedDate}";
      };
      stable = {
        src = dwl-stable-src;
        version = lib.removeSuffix "-dev" (configVersion dwl-stable-src);
      };
    };

    mkDwl = pkgs: channel:
      pkgs.callPackage ./nix/package.nix {
        inherit (channels.${channel}) src version;
        inherit channel dwlPatches;
      };

    compatible = channel: name: lib.elem name dwlPatches.compatible.${channel};

    genIndexArgs = "${dwl-patches-src} main=${dwl-src} stable=${dwl-stable-src}";
  in {
    packages = forAllSystems (pkgs: rec {
      dwl = mkDwl pkgs "main";
      dwl-stable = mkDwl pkgs "stable";
      default = dwl;

      gen-index = pkgs.writeShellApplication {
        name = "gen-index";
        runtimeInputs = with pkgs; [gnupatch jq gawk coreutils gnugrep gnused];
        text = builtins.readFile ./nix/gen-index.sh;
      };

      update-index = pkgs.writeShellApplication {
        name = "update-index";
        runtimeInputs = [pkgs.jq];
        text = ''
          ${lib.getExe gen-index} ${genIndexArgs} > nix/patches.json
          for channel in main stable; do
            echo "$channel: $(jq --arg c "$channel" '[.[] | select(.default[$c])] | length' nix/patches.json)/$(jq length nix/patches.json) patches apply"
          done
        '';
      };

      update = pkgs.writeShellApplication {
        name = "update";
        runtimeInputs = with pkgs; [git gnused gnugrep coreutils];
        text = ''
          latest=$(git ls-remote --tags --refs https://codeberg.org/dwl/dwl.git \
            | sed 's|.*refs/tags/||' | grep -E '^v[0-9.]+$' | sort -V | tail -n1)
          sed -i -E "s|(codeberg.org/dwl/dwl\?ref=refs/tags/)[^&\"]+|\1$latest|" flake.nix
          nix flake update
          nix run .#update-index
        '';
      };
    });

    overlays.default = final: _: {
      dwl-git = mkDwl final "main";
    };

    nixosModules.default = import ./nix/nixos-module.nix mkDwl;
    homeModules.default = import ./nix/hm-module.nix mkDwl;
    homeManagerModules.default = self.homeModules.default;

    inherit (dwlPatches) patches variants;

    lib = {
      inherit mkDwl;
      inherit (import ./nix/config.nix {inherit lib;}) c;
      inherit (dwlPatches) index compatible resolve;
    };

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        inputsFrom = [self.packages.${pkgs.stdenv.hostPlatform.system}.dwl];
      };
    });

    checks = forAllSystems (pkgs: let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) dwl dwl-stable gen-index;
      moduleDwl =
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            self.nixosModules.default
            {
              programs.dwl = {
                enable = true;
                modKey = "Super";
                autostart = lib.optionals (compatible "main" "autostart") ["true"];
                keybinds = {
                  "Mod+Return".spawn = "foot";
                  "Mod+d".spawn = ["fuzzel" "--list-executables-in-path"];
                  "Mod+q" = "killclient";
                  "Mod+h".setmfact = -0.05;
                  "Mod+F1".view = 1;
                  "Mod+Shift+F2".tag = [1 2];
                  "Mod+m".setlayout = 2;
                  "Mod+comma".focusmon = "left";
                  "Mod+j" = {
                    fn = "focusstack";
                    arg = 1;
                  };
                };
                rules = [
                  {
                    id = "firefox";
                    tags = [2];
                  }
                  {
                    title = "Picture-in-Picture";
                    floating = true;
                  }
                ];
                monitors = [
                  {
                    name = "eDP-1";
                    scale = 1.5;
                  }
                ];
                settings = {
                  borderpx = 2;
                  sloppyfocus = false;
                  focuscolor = "#89b4fa";
                  fullscreen_bg = [0.1 0.1 0.1 1.0];
                  accel_speed = -0.5;
                  accel_profile = "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
                  xkb_rules = {
                    layout = "us,de";
                    options = "grp:alt_shift_toggle";
                  };
                  layouts = with self.lib; [
                    {
                      symbol = "[]=";
                      arrange = c "tile";
                    }
                    {symbol = "><>";}
                    {
                      symbol = "[M]";
                      arrange = c "monocle";
                    }
                  ];
                };
              };
            }
          ];
        }).config.programs.dwl.package;
    in
      {
        inherit dwl dwl-stable;
        dwl-no-xwayland = dwl.override {enableXWayland = false;};
        dwl-own-keybinds-only = dwl.override {
          defaultKeybinds = false;
          keybinds."Super+Return".spawn = "foot";
        };
        nixos-module = moduleDwl;
        index-fresh = pkgs.runCommand "dwl-patches-index-fresh" {} ''
          ${lib.getExe gen-index} ${genIndexArgs} > fresh.json
          diff -u ${./nix/patches.json} fresh.json
          touch $out
        '';
      }
      // lib.optionalAttrs (compatible "stable" "bar") {
        dwl-stable-bar = dwl-stable.override {patches = ["bar"];};
      });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
