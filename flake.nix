{
  description = "NixOS/Darwin configuration with Home Manager";

  inputs = {
    # Core
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

    # Shell plugins
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

    # Tmux plugins
    tmux-pain-control = {
      url = "github:tmux-plugins/tmux-pain-control/2db63de3b08fc64831d833240749133cecb67d92";
      flake = false;
    };
    tmux-catppuccin = {
      url = "github:catppuccin/tmux/2c4cb5a07a3e133ce6d5382db1ab541a0216ddc7";
      flake = false;
    };

    # Full Neovim config exposed as a Home Manager module.
    nvimconf = {
      url = "github:OlegHQ/nvim-config?ref=dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      # Default user — override via _module.args if needed
      defaultUser = "snowbear";

      # Bleeding-edge packages from unstable
      overlays = [
        (final: prev:
          let unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
          in {
            vimPlugins = unstable.vimPlugins;
            bun = unstable.bun;
            d2 = unstable.d2;
            helm-ls = unstable.helm-ls;
          })
        # direnv's fish-based test suite gets killed in the darwin sandbox; skip it.
        (final: prev: {
          direnv =
            if prev.stdenv.isDarwin then
              prev.direnv.overrideAttrs (old: {
                doCheck = false;
                doInstallCheck = false;
              })
            else
              prev.direnv;
        })
      ];

      hmExtras = { full ? false }: (if full then [
        inputs.nvimconf.homeManagerModules.default
        {
          programs.nvimconf.enable = true;
          programs.nvimconf.theme = "catppuccin_latte";
          programs.nvimconf.themeMode = "light";
        }
      ] else []);

      # Single parameterized Darwin builder (was mkDarwin + mkDarwinFull)
      mkDarwin = name: { system, user, full ? false }:
        darwin.lib.darwinSystem {
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
                ] ++ hmExtras { inherit full; };
              };
            }
            {
              config._module.args = {
                currentSystemName = name;
                currentSystem = system;
                userName = user;
                userHomeDarwin = "/Users/${user}";
              };
            }
          ];
        };

      # Single parameterized Home Manager builder (was mkHome + mkHomeFull)
      mkHome = { system, user, full ? false, extraModules ? [] }:
        let pkgs = nixpkgs.legacyPackages.${system};
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            { _module.args.pkgsPath = pkgs.path; }
            {
              nixpkgs.overlays = overlays;
              home.username = user;
              home.homeDirectory = "/home/${user}";
            }
            (import ./home/default.nix { inherit inputs; })
          ] ++ hmExtras { inherit full; } ++ extraModules;
        };

      mkContainerImage = { system, user }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          uidEnv = builtins.getEnv "CONTAINER_UID";
          gidEnv = builtins.getEnv "CONTAINER_GID";
        in
        import ./container {
          inherit pkgs;
          homeConfiguration = mkHome {
            inherit system user;
            full = true;
            extraModules = [ ./container/home.nix ];
          };
          userName = user;
          uid = if uidEnv == "" then "1000" else uidEnv;
          gid = if gidEnv == "" then "1000" else gidEnv;
        };

    in {
      darwinConfigurations = {
        mac = mkDarwin "mac" {
          system = "aarch64-darwin";
          user = defaultUser;
        };
        mac-full = mkDarwin "mac-full" {
          system = "aarch64-darwin";
          user = defaultUser;
          full = true;
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
        "${defaultUser}-full-x86_64" = mkHome {
          system = "x86_64-linux";
          user = defaultUser;
          full = true;
        };
        "${defaultUser}-full-aarch64" = mkHome {
          system = "aarch64-linux";
          user = defaultUser;
          full = true;
        };
      };

      packages = {
        aarch64-linux = {
          containerImage = mkContainerImage {
            system = "aarch64-linux";
            user = defaultUser;
          };
          default = self.packages.aarch64-linux.containerImage;
        };
      };
    };
}
