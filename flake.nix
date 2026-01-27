# Advanced NixOS flake configuration with multi-platform support
{
  description = "Advanced NixOS configuration with Darwin support";

  inputs = {
    # Core Nix channels
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # System managers
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Shell & terminal enhancements
    fish-fzf = {
      url = "github:jethrokuan/fzf/24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
      flake = false;
    };
    fish-foreign-env = {
      url =
        "github:oh-my-fish/plugin-foreign-env/dddd9213272a0ab848d474d0cbde12ad034e65bc";
      flake = false;
    };
    fish-async-prompt = {
      url = "github:acomagu/fish-async-prompt";
      flake = false;
    };
    # Tmux plugins
    tmux-pain-control = {
      url =
        "github:tmux-plugins/tmux-pain-control/2db63de3b08fc64831d833240749133cecb67d92";
      flake = false;
    };
    tmux-catppuccin = {
      url = "github:catppuccin/tmux/2c4cb5a07a3e133ce6d5382db1ab541a0216ddc7";
      flake = false;
    };
    # Neovim configuration module (for full config)
    nvimconf = {
      url = "github:OlegHQ/nvim-config?ref=dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Claude Code configuration module
    claude-config = {
      url = "github:OlegHQ/claude-config?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      # System user configuration (auto-detected from environment)
      # Use SUDO_USER if running under sudo, otherwise fall back to USER
      userName = let
        sudoUser = builtins.getEnv "SUDO_USER";
        envUser = builtins.getEnv "USER";
      in if sudoUser != "" then
        sudoUser
      else if envUser != "" then
        envUser
      else
        "snowbear";
      # Build a nix-darwin system
      mkDarwin = name:
        { system, user }:
        darwin.lib.darwinSystem rec {
          inherit system inputs;
          modules = [
            { nixpkgs.overlays = overlays; }
            ./darwin/system.nix
            ./darwin/account.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${user} = {
                imports = [
                  (import ./home/default.nix { inherit inputs; })
                  inputs.claude-config.homeManagerModules.default
                ];
                programs.claude-config.enable = true;
                programs.claude-config.themeMode = "dark";
              };
            }
            {
              config._module.args = {
                currentSystemName = name;
                currentSystem = system;
                userName = userName;
                userHomeDarwin = "/Users/${userName}";
              };
            }
          ];
        };

      # Build a nix-darwin system with nvimconf (full config)
      mkDarwinFull = name:
        { system, user }:
        darwin.lib.darwinSystem rec {
          inherit system inputs;
          modules = [
            { nixpkgs.overlays = overlays; }
            ./darwin/system.nix
            ./darwin/account.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${user} = {
                imports = [
                  (import ./home/default.nix { inherit inputs; })
                  inputs.nvimconf.homeManagerModules.default
                  inputs.claude-config.homeManagerModules.default
                ];
                programs.nvimconf.enable = true;
                programs.nvimconf.theme = "catppuccin_macchiato";
                programs.nvimconf.themeMode = "dark";
                programs.claude-config.enable = true;
                programs.claude-config.themeMode = "dark";
              };
            }
            {
              config._module.args = {
                currentSystemName = name;
                currentSystem = system;
                userName = userName;
                userHomeDarwin = "/Users/${userName}";
              };
            }
          ];
        };

      # Package overlays for enhanced functionality and bleeding-edge tools
      overlays = [
        # Bleeding-edge packages from unstable
        (final: prev:
          let
            unstable =
              inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
          in {
            vimPlugins = unstable.vimPlugins;
            bun = unstable.bun;
            helix = unstable.helix;
            gdb = unstable.gdb;
            d2 = unstable.d2;
            k3d = unstable.k3d;
            kubectl = unstable.kubectl;
            awscli2 = unstable.awscli2;
            helm-ls = unstable.helm-ls;
            gemini-cli = unstable.gemini-cli;
            claude-code = unstable.claude-code;
            codex = unstable.codex;

            # Packages with broken builds in stable nixpkgs-25.11
            dotnet-sdk = unstable.dotnet-sdk; # requires LLVM rebuild in stable
          })
        # Custom Neovim configuration overlay with pinned plugin versions
        (import ./home/nvim.nix { inherit inputs; })
      ];

      # Build a Home Manager configuration for a given linux system
      mkHome = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hmModule = import ./home/default.nix { inherit inputs; };
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            { _module.args.pkgsPath = pkgs.path; }
            {
              nixpkgs.overlays = overlays;
              home.username = userName;
              home.homeDirectory = "/home/${userName}";
            }
            hmModule
            inputs.claude-config.homeManagerModules.default
            {
              programs.claude-config.enable = true;
              programs.claude-config.themeMode = "dark";
            }
          ];
        };

      # Build a Home Manager configuration with nvimconf (full config)
      mkHomeFull = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hmModule = import ./home/default.nix { inherit inputs; };
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            { _module.args.pkgsPath = pkgs.path; }
            {
              nixpkgs.overlays = overlays;
              home.username = userName;
              home.homeDirectory = "/home/${userName}";
            }
            hmModule
            inputs.nvimconf.homeManagerModules.default
            inputs.claude-config.homeManagerModules.default
            {
              programs.nvimconf.enable = true;
              programs.nvimconf.theme = "catppuccin_macchiato";
              programs.nvimconf.themeMode = "dark";
              programs.claude-config.enable = true;
              programs.claude-config.themeMode = "dark";
            }
          ];
        };
    in {
      darwinConfigurations = {
        mac = mkDarwin "mac" {
          system = "aarch64-darwin";
          user = userName;
        };
        mac-full = mkDarwinFull "mac-full" {
          system = "aarch64-darwin";
          user = userName;
        };
      };

      homeConfigurations = {
        "${userName}-x86_64" = mkHome "x86_64-linux";
        "${userName}-aarch64" = mkHome "aarch64-linux";
        "${userName}-full-x86_64" = mkHomeFull "x86_64-linux";
        "${userName}-full-aarch64" = mkHomeFull "aarch64-linux";
      };
    };
}

