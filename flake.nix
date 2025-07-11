{
  description = "NixOS and nix-darwin configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.11";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, home-manager, flake-utils }:
    let
      systems = {
        darwin = {
          system = "aarch64-darwin";
          hostname = "macbook";
          username = "snowbear";
        };
        linux = {
          system = "x86_64-linux";
          hostname = "ubuntu";
          username = "snowbear";
        };
      };
      mkDarwin = systemConfig:
        let
          pkgs = nixpkgs.legacyPackages.${systemConfig.system};
          stable-pkgs = nixpkgs-stable.legacyPackages.${systemConfig.system};
        in
        nix-darwin.lib.darwinSystem {
          system = systemConfig.system;
          modules = [
            ./darwin/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${systemConfig.username}.imports = [ ./home-manager/home.nix ];
              home-manager.extraSpecialArgs = {
                system = systemConfig.system;
                pkgs = pkgs;
                stable-pkgs = stable-pkgs;
                lib = pkgs.lib;
              };
            }
            {
              networking.hostName = systemConfig.hostname;
              system.defaults.dock.autohide = true;
              system.defaults.dock.mru-spaces = false;
              system.defaults.dock.show-recents = false;
              system.defaults.dock.tilesize = 48;
              system.defaults.finder.AppleShowAllExtensions = true;
              system.defaults.finder.ShowPathbar = true;
              system.defaults.finder.ShowStatusBar = true;
              system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
              system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
              system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
            }
          ];
        };
      mkHome = systemConfig:
        let
          pkgs = nixpkgs.legacyPackages.${systemConfig.system};
          stable-pkgs = nixpkgs-stable.legacyPackages.${systemConfig.system};
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home-manager/home.nix ];
          extraSpecialArgs = {
            system = systemConfig.system;
            pkgs = pkgs;
            stable-pkgs = stable-pkgs;
            lib = pkgs.lib;
          };
          username = systemConfig.username;
          homeDirectory = "/home/${systemConfig.username}";
        };
    in
    {
      darwinConfigurations.${systems.darwin.hostname} = mkDarwin systems.darwin;
      homeConfigurations.${systems.linux.username} = mkHome systems.linux;
      devShells = flake-utils.lib.eachDefaultSystem (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              git git-lfs vim wget curl jq ripgrep fd tree htop tmux
              nixpkgs-fmt statix deadnix
            ];
            shellHook = ''
              echo "Welcome to NixOS/nix-darwin/home-manager development shell!"
              echo "Available commands:"
              echo "  make darwin-switch  - Switch to darwin configuration"
              echo "  make home-switch    - Switch to home-manager configuration (Linux)"
            '';
          };
        });
      formatter = flake-utils.lib.eachDefaultSystem (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt
      );
    };
} 
