{
  description = "dwl and dwl-patches for Nix: main and stable builds, patches by name, declarative config, NixOS and Home Manager modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

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
    nixpkgs-stable,
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
      dwl-stable-git = mkDwl final "stable";
    };

    nixosModules = rec {
      dwl = {
        key = "dwl-flake#nixosModules.dwl";
        imports = [
          (import ./nix/nixos-module.nix {
            inherit mkDwl;
            homeModule = self.homeModules.dwl;
          })
        ];
      };
      default = dwl;
    };

    homeModules = rec {
      dwl = {
        key = "dwl-flake#homeModules.dwl";
        imports = [(import ./nix/hm-module.nix mkDwl)];
      };
      default = dwl;
    };
    homeManagerModules = self.homeModules;

    hjemModules = rec {
      dwl = {
        key = "dwl-flake#hjemModules.dwl";
        imports = [(import ./nix/hjem-module.nix mkDwl)];
      };
      default = dwl;
    };

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
    checks = forAllSystems (pkgs:
      import ./nix/checks.nix {
        inherit self lib pkgs nixpkgs nixpkgs-stable compatible genIndexArgs;
      });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
