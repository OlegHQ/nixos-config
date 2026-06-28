{ self
, inputs
, overlays
}:

let
  defaultUser = "snowbear";
  nixpkgs = inputs.nixpkgs;

  pkgsFor = system:
    import nixpkgs {
      inherit overlays system;
    };

  hmExtras = { full ? false }:
    if full then [
      inputs.nvimconf.homeManagerModules.default
      {
        programs.nvimconf.enable = true;
        programs.nvimconf.theme = "catppuccin_latte";
        programs.nvimconf.themeMode = "light";
      }
    ] else [];

  mkDarwin = name: { system, user, full ? false }:
    inputs.darwin.lib.darwinSystem {
      inherit inputs system;
      modules = [
        { nixpkgs.overlays = overlays; }
        ../darwin/system.nix
        ../darwin/account.nix
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user}.imports = [
            (import ../home/default.nix { inherit inputs full; })
          ] ++ hmExtras { inherit full; };
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

  mkHome = { system, user, full ? false, extraModules ? [] }:
    let pkgs = pkgsFor system;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        { _module.args.pkgsPath = pkgs.path; }
        {
          home.username = user;
          home.homeDirectory = "/home/${user}";
        }
        (import ../home/default.nix { inherit inputs full; })
      ] ++ hmExtras { inherit full; } ++ extraModules;
    };

in {
  inherit defaultUser mkDarwin mkHome;
}
