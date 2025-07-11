{ config, pkgs, lib, ... }:

{
  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "UTC";

  # Select internationalisation properties
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable sound with pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable fish shell
  programs.fish.enable = true;

  # Enable fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    source-code-pro
    font-awesome
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
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
    pinentry
    
    # Media
    ffmpeg
    imagemagick
    
    # Nix development
    nixpkgs-fmt
    statix
    deadnix
    
    # GUI applications
    firefox
    vscode
    discord
    slack
    spotify
    docker
    postman
  ];

  # Enable shell integration
  environment.shells = with pkgs; [ fish zsh bash ];

  # Enable services
  services = {
    # SSH
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    
    # GPG agent
    pcscd.enable = true;
    gnome.gnome-keyring.enable = true;
    
    # Docker
    docker.enable = true;
    
    # Flatpak
    flatpak.enable = true;
  };

  # Security settings
  security = {
    # Enable sudo
    sudo.enable = true;
    sudo.wheelNeedsPassword = false;
    
    # Enable polkit
    polkit.enable = true;
  };

  # Networking
  networking = {
    # Enable firewall
    firewall.enable = true;
    firewall.allowedTCPPorts = [ 22 80 443 ];
    firewall.allowedUDPPorts = [ 53 ];
    
    # DNS settings
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };

  # System preferences
  system = {
    # Auto upgrade
    autoUpgrade = {
      enable = true;
      channel = "https://nixos.org/channels/nixos-unstable";
    };
    
    # State version
    stateVersion = "23.11";
  };

  # Users
  users.users.snowbear = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
      # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
    ];
  };

  # Enable flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Hardware configuration
  hardware = {
    # Enable opengl
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    
    # Enable pulseaudio
    pulseaudio.enable = false; # Disabled in favor of pipewire
    
    # Enable bluetooth
    bluetooth.enable = true;
    
    # Enable firmware updates
    firmware = with pkgs; [
      linux-firmware
      intel-microcode
      amdvlk
    ];
  };

  # Power management
  powerManagement.cpuFreqGovernor = "performance";

  # File systems
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  swapDevices = [ ];

  # Enable swap on zram
  zramSwap.enable = true;
} 
