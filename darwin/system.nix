{ config, pkgs, userName, ... }:

let
  mkHandler = contentType: {
    LSHandlerContentType = contentType;
    LSHandlerRoleAll = "com.mitchellh.ghostty";
    LSHandlerPreferredVersions = { LSHandlerRoleAll = "-"; };
  };

in {
  system.stateVersion = 5;
  system.primaryUser = userName;

  nixpkgs.config.allowUnfree = true;

  # Nix managed by external installer
  nix = {
    enable = false;
    nixPath = pkgs.lib.mkForce [ ];
    settings = {
      substituters = [ "https://cache.nixos.org/" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };

  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
  '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
  '';

  environment.shells = with pkgs; [ bashInteractive zsh fish ];
  environment.systemPackages = with pkgs; [ rustup wget ];

  system.defaults.CustomUserPreferences = {
    "com.apple.LaunchServices" = {
      LSHandlers = map mkHandler [
        "public.plain-text"
        "public.source-code"
        "public.shell-script"
        "net.daringfireball.markdown"
        "public.lua-script"
        "public.data"
        "public.text"
        "public.unix-executable"
      ];
    };
  };
}
