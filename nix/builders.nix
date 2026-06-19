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
            (import ../home/default.nix { inherit inputs; })
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
        (import ../home/default.nix { inherit inputs; })
      ] ++ hmExtras { inherit full; } ++ extraModules;
    };

  mkContainerImage = { system, user }:
    let
      pkgs = pkgsFor system;
      uidEnv = builtins.getEnv "CONTAINER_UID";
      gidEnv = builtins.getEnv "CONTAINER_GID";
    in
    import ../container {
      inherit pkgs;
      homeConfiguration = mkHome {
        inherit system user;
        full = true;
        extraModules = [ ../container/home.nix ];
      };
      userName = user;
      uid = if uidEnv == "" then "1000" else uidEnv;
      gid = if gidEnv == "" then "1000" else gidEnv;
    };
in {
  inherit defaultUser mkContainerImage mkDarwin mkHome;
}
