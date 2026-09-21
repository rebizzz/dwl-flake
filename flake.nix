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
      url = "git+https://codeberg.org/dwl/dwl?ref=0.8&shallow=1";
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
        runtimeInputs = with pkgs; [gnupatch jq gawk coreutils ripgrep gnused];
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

      docs = import ./nix/docs.nix {inherit pkgs nixpkgs self;};

      update-docs = pkgs.writeShellScriptBin "update-docs" "install -m644 ${docs} docs.md";

      verify-patches = pkgs.writeShellApplication {
        name = "verify-patches";
        runtimeInputs = [pkgs.jq];
        text = builtins.readFile ./nix/verify-patches.sh;
      };

      compare-upstream = pkgs.writeShellApplication {
        name = "compare-upstream";
        runtimeInputs = with pkgs; [git jq gnupatch diffutils coreutils];
        text = builtins.readFile ./nix/compare-upstream.sh;
      };

      update = pkgs.writeShellApplication {
        name = "update";
        runtimeInputs = with pkgs; [git gnused ripgrep coreutils];
        text = ''
          remote=https://codeberg.org/dwl/dwl.git
          tags=$(git ls-remote --tags --refs "$remote" | sed 's|.*refs/tags/v||')
          latest=$(git ls-remote --heads "$remote" | sed 's|.*refs/heads/||' | rg '^[0-9]+\.[0-9]+$' \
            | while read -r b; do echo "$tags" | rg -qxF "$b" && echo "$b"; done | sort -V | tail -n1)
          sed -i -E "s|(codeberg.org/dwl/dwl\?ref=)[0-9.]+|\1$latest|" flake.nix
          nix flake update
          nix run .#update-index
          nix run .#verify-patches
          nix run .#update-docs
        '';
      };
    });

    apps = forAllSystems (pkgs: rec {
      dwl = {
        type = "app";
        program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.dwl}/bin/dwl";
      };
      dwl-stable = {
        type = "app";
        program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.dwl-stable}/bin/dwl";
      };
      default = dwl;
    });

    overlays = rec {
      default = final: prev: {
        dwl = mkDwl final "main";
        dwl-git = mkDwl final "main";
        dwl-stable = mkDwl final "stable";
        dwl-stable-git = mkDwl final "stable";
      };
      dwl = default;
      dwl-stable = final: prev: {
        dwl = mkDwl final "stable";
        dwl-stable = mkDwl final "stable";
        dwl-stable-git = mkDwl final "stable";
      };
    };

    nixosModules = rec {
      dwl = {
        key = "dwl-flake#nixosModules.dwl";
        imports = [
          (import ./nix/nixos-module.nix {
            inherit mkDwl;
            homeModule = self.homeModules.dwl;
            homeStylixModule = self.homeModules.stylix;
          })
        ];
      };
      default = dwl;
      stylix = {
        key = "dwl-flake#nixosModules.stylix";
        imports = [./nix/stylix.nix];
      };
    };

    homeModules = rec {
      dwl = {
        key = "dwl-flake#homeModules.dwl";
        imports = [(import ./nix/hm-module.nix mkDwl)];
      };
      stylix = {
        key = "dwl-flake#homeModules.stylix";
        imports = [./nix/stylix.nix];
      };
      default = dwl;
    };

    hjemModules = rec {
      dwl = {
        key = "dwl-flake#hjemModules.dwl";
        imports = [(import ./nix/hjem-module.nix mkDwl)];
      };
      default = dwl;
    };

    lib = {
      inherit mkDwl;
      inherit (import ./nix/config.nix {inherit lib;}) c;
      inherit (dwlPatches) index compatible resolve fileFor requiredBy patches variants;
      upstreamPlan = lib.genAttrs ["main" "stable"] (channel:
        map (name: let
          dep = dwlPatches.requiredBy channel name;
        in {
          inherit name;
          file = dwlPatches.fileFor channel name;
          requires =
            if dep == null
            then null
            else {
              name = dep;
              file = dwlPatches.fileFor channel dep;
            };
        })
        dwlPatches.compatible.${channel});
      verifyPlan = lib.concatMap (channel:
        lib.mapAttrsToList (name: p: {
          inherit channel name;
          candidates = let
            ok = lib.attrNames (lib.filterAttrs (_: f: f.applies.${channel}) p.files);
          in
            [p.default.${channel}] ++ lib.remove p.default.${channel} ok;
        }) (lib.filterAttrs (_: p: p.default.${channel} != null) dwlPatches.index)) ["main" "stable"];
      actions = lib.mapAttrs (_: ch:
        lib.sort lib.lessThan (lib.concatMap (m: lib.optional (lib.isList m) (lib.head m))
          (builtins.split "\n([a-z_]+)\\(const Arg \\*arg\\)\n" (builtins.readFile "${ch.src}/dwl.c"))))
      channels;
    };

    legacyPackages = forAllSystems (pkgs: {
      variantTests = lib.genAttrs ["main" "stable"] (channel:
        lib.mapAttrs (name: p:
          lib.mapAttrs (file: _: (mkDwl pkgs channel).override {patches = ["${name}:${file}"];})
          (lib.filterAttrs (_: f: f.applies.${channel}) p.files))
        dwlPatches.index);

      patchedSources = lib.genAttrs ["main" "stable"] (channel:
        lib.genAttrs dwlPatches.compatible.${channel} (name:
          ((mkDwl pkgs channel).override {patches = [name];}).overrideAttrs {
            name = "dwl-source-${channel}-${name}";
            outputs = ["out"];
            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
            installPhase = "cp -r . $out";
          }));

      patchedSourcesAll = pkgs.linkFarm "dwl-patched-sources" (lib.concatMap (channel:
        map (name: {
          name = "${channel}/${name}";
          path = self.legacyPackages.${pkgs.stdenv.hostPlatform.system}.patchedSources.${channel}.${name};
        })
        dwlPatches.compatible.${channel}) ["main" "stable"]);
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        inputsFrom = [self.packages.${pkgs.stdenv.hostPlatform.system}.dwl];
        packages = with pkgs; [
          just
          git
          jq
          gnupatch
          ripgrep
        ];
      };
    });
    checks = forAllSystems (pkgs:
      import ./nix/checks.nix {
        inherit self lib pkgs nixpkgs nixpkgs-stable compatible genIndexArgs;
      });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
