{ pkgs, ... }: {
  # Helix editor + tooling
  packages = [
    pkgs.helix
    pkgs.nil
    pkgs.nixfmt-classic
    pkgs.pyright
    pkgs.black # python formatter
  ];

  languages = builtins.readFile ./configs/languages.toml;
  config = builtins.readFile ./configs/helixconfig.toml;
}
