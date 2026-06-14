# Home Manager entry point — imports only, minimal inline config
{ inputs, ... }:
{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./shell.nix { inherit inputs; })
    (import ./tmux.nix { inherit inputs; })
    ./editor.nix
    ./git.nix
    ./terminal.nix
    ./packages.nix
  ];

  home.stateVersion = "18.09";

  xdg.enable = true;

  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.cargo/bin" ];

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
    GOBIN = "$HOME/.local/bin";
  };

  home.file.".inputrc".source = ./configs/inputrc;
  home.file.".hushlogin".text = "";
  home.file.".usqlrc".source = ./configs/usqlrc;

  xdg.configFile = {
    "zed/settings.json".source = ./configs/zed-settings.json;
    "zed/keymap.json".source = ./configs/zed-keymap.json;
    "zed/themes/opencode-oc1-dark.json".source = ./configs/opencode-oc1-dark-zed.json;
  };

  programs.gpg.enable = !pkgs.stdenv.isDarwin;
}
