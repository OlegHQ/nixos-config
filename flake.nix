{
  description = "NixOS and nix-darwin configuration flake";

  inputs = {
    # Core flakes
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.11";
    
    # Darwin specific
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Additional flakes
    flake-utils.url = "github:numtide/flake-utils";
    
    # Optional: Add more flakes as needed
    # neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, home-manager, flake-utils }:
    let
      # System configurations
      systems = {
        # Darwin (M1 Mac)
        darwin = {
          system = "aarch64-darwin";
          hostname = "macbook";
          username = "snowbear";
        };
        
        # Linux (Ubuntu)
        linux = {
          system = "x86_64-linux";
          hostname = "ubuntu";
          username = "snowbear";
        };
      };

      # Helper function to create system-specific configurations
      mkSystem = systemConfig: systemType:
        let
          pkgs = nixpkgs.legacyPackages.${systemConfig.system};
          stable-pkgs = nixpkgs-stable.legacyPackages.${systemConfig.system};
        in
        if systemType == "darwin" then
          nix-darwin.lib.darwinSystem {
            system = systemConfig.system;
            modules = [
              # Main configuration
              ./darwin/configuration.nix
              
              # Home manager integration
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.${systemConfig.username} = import ./home-manager/home.nix {
                  inherit pkgs stable-pkgs;
                  system = systemConfig.system;
                };
              }
              
              # System-specific configuration
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
          }
        else
          nixpkgs.lib.nixosSystem {
            system = systemConfig.system;
            modules = [
              # Main configuration
              ./nixos/configuration.nix
              
              # Home manager integration
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.${systemConfig.username} = import ./home-manager/home.nix {
                  inherit pkgs stable-pkgs;
                  system = systemConfig.system;
                };
              }
              
              # System-specific configuration
              {
                networking.hostName = systemConfig.hostname;
                users.users.${systemConfig.username} = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" "networkmanager" ];
                  shell = pkgs.fish;
                };
              }
            ];
          };
    in
    {
      # Darwin configuration
      darwinConfigurations.${systems.darwin.hostname} = mkSystem systems.darwin "darwin";
      
      # NixOS configuration
      nixosConfigurations.${systems.linux.hostname} = mkSystem systems.linux "linux";
      
      # Development shell
      devShells = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # Development tools
              git
              git-lfs
              vim
              wget
              curl
              jq
              ripgrep
              fd
              tree
              htop
              tmux
              
              # Nix development
              nixpkgs-fmt
              statix
              deadnix
            ];
            
            shellHook = ''
              echo "Welcome to NixOS/nix-darwin development shell!"
              echo "Available commands:"
              echo "  make darwin-switch  - Switch to darwin configuration"
              echo "  make linux-switch   - Switch to linux configuration"
              echo "  make darwin-test    - Test darwin configuration"
              echo "  make linux-test     - Test linux configuration"
            '';
          };
        }
      );
      
      # Formatter
      formatter = flake-utils.lib.eachDefaultSystem (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt
      );
    };
} 
