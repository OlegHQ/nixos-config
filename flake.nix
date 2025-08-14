# Advanced NixOS flake configuration with multi-platform support
{
  description = "Advanced NixOS configuration with Darwin support";

  inputs = {
    # Core Nix channels
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # System managers
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    # Development tools
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };

    nvim-hotpot.url = "github:rktjmp/hotpot.nvim/v0.13.0";
    nvim-hotpot.flake = false;
    
    nvim-lspconfig.url = "github:neovim/nvim-lspconfig/03bc581e05e81d33808b42b2d7e76d70adb3b595";
    nvim-lspconfig.flake = false;
    
    nvim-comment.url = "github:numToStr/Comment.nvim/e30b7f2008e52442154b66f7c519bfd2f1e32acb";
    nvim-comment.flake = false;
    
    nvim-conform.url = "github:stevearc/conform.nvim/6feb2f28f9a9385e401857b21eeac3c1b66dd628";
    nvim-conform.flake = false;
    
    nvim-gitsigns.url = "github:lewis6991/gitsigns.nvim/f074844b60f9e151970fbcdbeb8a2cd52b6ef25a";
    nvim-gitsigns.flake = false;

    nvim-lualine.url = "github:nvim-lualine/lualine.nvim/a94fc68960665e54408fe37dcf573193c4ce82c9";
    nvim-lualine.flake = false;

    nvim-lsplines.url = "git+https://git.sr.ht/~whynothugo/lsp_lines.nvim?rev=a92c755f182b89ea91bd8a6a2227208026f27b4d";
    nvim-lsplines.flake = false;

    # Shell & terminal enhancements
    fish-fzf = {
      url = "github:jethrokuan/fzf/24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
      flake = false;
    };
    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env/dddd9213272a0ab848d474d0cbde12ad034e65bc";
      flake = false;
    };
    tmux-pain-control = {
      url = "github:tmux-plugins/tmux-pain-control/2db63de3b08fc64831d833240749133cecb67d92";
      flake = false;
    };
    tmux-catppuccin = {
      url = "github:catppuccin/tmux/2c4cb5a07a3e133ce6d5382db1ab541a0216ddc7";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      # System user configuration
      userName = "snowbear";
      # Build a nix-darwin system
      mkDarwin = name: { system, user }:
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
              home-manager.users.${user} = import ./home/default.nix { inherit inputs; };
            }
            { config._module.args = { currentSystemName = name; currentSystem = system; userName = userName; userHomeDarwin = "/Users/${userName}"; }; }
          ];
        };

      # Package overlays for enhanced functionality and bleeding-edge tools
      overlays = [
        (final: prev: let
          unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.system};
        in {
          # Bleeding-edge packages from unstable
          vimPlugins = unstable.vimPlugins;

          bun = unstable.bun;
          helix = unstable.helix;
          gdb = unstable.gdb;
          d2 = unstable.d2;
          k3d = unstable.k3d;
          kubectl = unstable.kubectl;
          awscli2 = unstable.awscli2;
          helm-ls = unstable.helm-ls;
          claude-code = unstable.claude-code;
        })
        # Custom Neovim configuration overlay with pinned plugin versions
        (import ./home/nvim.nix { inherit inputs; })
      ];

      # Build a Home Manager configuration for a given linux system
      mkHome = system: let
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
        ];
      };
    in {
      darwinConfigurations.mac = mkDarwin "mac" { system = "aarch64-darwin"; user = userName; };

      homeConfigurations = {
        "${userName}-x86_64" = mkHome "x86_64-linux";
        "${userName}-aarch64" = mkHome "aarch64-linux";
      };
    };
}
