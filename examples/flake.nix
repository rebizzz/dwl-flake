{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dwl-flake = {
      url = "github:rebizzz/dwl-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    dwl-flake,
    ...
  } @ inputs: {
    nixosConfigurations = {
      nixos-only = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hardware-configuration.nix
          dwl-flake.nixosModules.default
          ./nixos.nix
        ];
      };

      with-home-manager = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hardware-configuration.nix
          dwl-flake.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            programs.dwl = {
              enable = true;
              useHomeManagerBuild = true;
            };
            home-manager.users.alice = {
              imports = [./home.nix];
              home.stateVersion = "26.05";
            };
          }
        ];
      };
    };

    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        dwl-flake.homeModules.default
        ./home.nix
        {
          home = {
            username = "alice";
            homeDirectory = "/home/alice";
            stateVersion = "26.05";
          };
        }
      ];
    };

    packages.x86_64-linux.default = import ./package.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit dwl-flake;
    };
  };
}
