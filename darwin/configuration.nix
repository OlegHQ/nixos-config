{ config, pkgs, lib, ... }:

{
  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Enable fish shell
  programs.fish.enable = true;

  # Set Git commit hash for nixpkgs pinning
  system.configurationRevision = "flake";

  # Used for backwards compatibility, please read the changelog before changing.
  system.stateVersion = 4;

  # Enable fonts
  fonts.fontDir.enable = true;
  fonts.fonts = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    source-code-pro
    font-awesome
  ];

  # Enable system packages
  environment.systemPackages = with pkgs; [
    # Core utilities
    git
    git-lfs
    vim
    wget
    curl
    jq
    ripgrep
    fd
    tree
    htop
    tmux
    bat
    exa
    fzf
    zoxide
    
    # Development tools
    gcc
    clang
    cmake
    pkg-config
    
    # Network tools
    mtr
    nmap
    wireshark
    
    # Security
    gnupg
    pinentry_mac
    
    # Media
    ffmpeg
    imagemagick
    
    # Nix development
    nixpkgs-fmt
    statix
    deadnix
  ];

  # Enable shell integration
  environment.shells = with pkgs; [ fish zsh bash ];

  # Enable services
  services = {
    # SSH
    ssh.enable = true;
    
    # Keychain
    keychain.enable = true;
    keychain.enableSshSupport = true;
    
    # GPG agent
    gpg-agent.enable = true;
    gpg-agent.enableSshSupport = true;
    
    # Launch agents
    launchd.daemons = {
      # Add custom launch agents here
    };
  };

  # Security settings
  security = {
    # Enable sudo with touch ID
    pam.enableSudoTouchIdAuth = true;
    
    # Disable guest account
    guestAccount.enable = false;
  };

  # Networking
  networking = {
    # Enable firewall
    firewall.enable = true;
    firewall.allowPing = true;
    
    # DNS settings
    dns = [ "1.1.1.1" "8.8.8.8" ];
  };

  # System preferences
  system.defaults = {
    # Dock
    dock.autohide = true;
    dock.mru-spaces = false;
    dock.show-recents = false;
    dock.tilesize = 48;
    dock.orientation = "left";
    
    # Finder
    finder.AppleShowAllExtensions = true;
    finder.ShowPathbar = true;
    finder.ShowStatusBar = true;
    finder.FXPreferredViewStyle = "Nlsv"; # List view
    
    # Global domain
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.KeyRepeat = 2;
    
    # Screensaver
    loginwindow.GuestEnabled = false;
    
    # Screenshots
    screencapture.location = "~/Desktop";
    screencapture.type = "png";
    
    # Trackpad
    trackpad.Clicking = true;
    trackpad.TrackpadThreeFingerDrag = true;
  };

  # Users
  users.users.snowbear = {
    name = "snowbear";
    home = "/Users/snowbear";
    shell = pkgs.fish;
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Home directory
  homebrew = {
    enable = true;
    global.brewfile = true;
    global.lockfiles = true;
    
    # Install packages
    brews = [
      "mas" # Mac App Store CLI
    ];
    
    # Install casks
    casks = [
      "visual-studio-code"
      "google-chrome"
      "firefox"
      "discord"
      "slack"
      "spotify"
      "docker"
      "postman"
      "rectangle" # Window management
      "alfred" # Spotlight replacement
    ];
    
    # Install Mac App Store apps
    masApps = {
      "1Password for Safari" = 1569813296;
      "Xcode" = 497799835;
    };
  };
} 
