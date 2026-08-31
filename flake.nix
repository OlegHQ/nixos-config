{
  description = "Nix, nix-darwin, Home Manager, and Multipass VM configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fish-fzf = {
      url = "github:jethrokuan/fzf/24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
      flake = false;
    };
    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env/dddd9213272a0ab848d474d0cbde12ad034e65bc";
      flake = false;
    };
    fish-async-prompt = {
      url = "github:acomagu/fish-async-prompt";
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

    nvimconf = {
      url = "github:OlegHQ/nvim-config?ref=dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... }@inputs:
    let
      overlays = import ./nix/overlays.nix { inherit inputs; };
      builders = import ./nix/builders.nix { inherit self inputs overlays; };
      inherit (builders) defaultUser mkDarwin mkHome;
    in {
      darwinConfigurations = {
        mac = mkDarwin "mac" {
          system = "aarch64-darwin";
          user = defaultUser;
        };
      };

      homeConfigurations = {
        "${defaultUser}-x86_64" = mkHome {
          system = "x86_64-linux";
          user = defaultUser;
        };
        "${defaultUser}-aarch64" = mkHome {
          system = "aarch64-linux";
          user = defaultUser;
        };
      };

      packages.aarch64-linux = {
        homeManager = inputs.home-manager.packages.aarch64-linux.home-manager;
        default = self.packages.aarch64-linux.homeManager;
      };

      apps.aarch64-linux.homeManager = {
        type = "app";
        program = "${self.packages.aarch64-linux.homeManager}/bin/home-manager";
      };
    };
}
