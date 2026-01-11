{ pkgs, ... }: {
  # Helix editor + tooling
  packages = [
    pkgs.helix
    # pkgs.nil  # TODO: re-enable when nix-functional-tests fixed in nixpkgs-25.11
    pkgs.nixfmt-classic
    pkgs.pyright
    # pkgs.black  # TODO: re-enable when setproctitle fixed in nixpkgs-25.11
  ];

  languages = builtins.readFile ./configs/languages.toml;
  config = builtins.readFile ./configs/helixconfig.toml;
}
