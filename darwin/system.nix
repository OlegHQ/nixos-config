{ config, pkgs, userName, ... }: {
  # macOS system configuration with nix-darwin
  system.stateVersion = 5;

  # Required for CustomUserPreferences
  system.primaryUser = userName;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix daemon configuration managed by external installer
  # nix.useDaemon = true;

  # Nix configuration settings
  nix = {
    enable = false;
    
    # Suppress legacy channel warnings
    nixPath = pkgs.lib.mkForce [ ];

    settings = {
      substituters = [ "https://cache.nixos.org/" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };

  # Shell configuration
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
  environment.systemPackages = with pkgs; [ cachix rustup gcc wget ];

  # File associations using CustomUserPreferences
  system.defaults.CustomUserPreferences = {
    "com.apple.LaunchServices" = {
      LSHandlers = [
        # Text files and source code open with Ghostty (which will use nvim due to EDITOR)
        {
          LSHandlerContentType = "public.plain-text";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        {
          LSHandlerContentType = "public.source-code";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        {
          LSHandlerContentType = "public.shell-script";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        # Markdown files
        {
          LSHandlerContentType = "net.daringfireball.markdown";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        # Lua files
        {
          LSHandlerContentType = "public.lua-script";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        # Files without extension (like LICENSE)
        {
          LSHandlerContentType = "public.data";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        # Text-based files
        {
          LSHandlerContentType = "public.text";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
        # Executables open with Ghostty (default terminal)
        {
          LSHandlerContentType = "public.unix-executable";
          LSHandlerRoleAll = "com.mitchellh.ghostty";
          LSHandlerPreferredVersions = {
            LSHandlerRoleAll = "-";
          };
        }
      ];
    };
  };
}


