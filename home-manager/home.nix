{ config, pkgs, lib, system, ... }:

let
  # Helper function to check if we're on darwin
  isDarwin = system == "aarch64-darwin" || system == "x86_64-darwin";
  
  # Helper function to check if we're on linux
  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
in
{
  # Home Manager needs a bit of information about you and the paths it should manage
  home.username = "snowbear";
  home.homeDirectory = if isDarwin then "/Users/snowbear" else "/home/snowbear";

  # This value determines the Home Manager release that your configuration is compatible with
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Enable fish shell
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Set fish greeting
      set fish_greeting ""
      
      # Set fish colors
      set fish_color_normal normal
      set fish_color_command 93d81f
      set fish_color_quote f9ee98
      set fish_color_redirection 9b5c2e
      set fish_color_end 9b5c2e
      set fish_color_error ff6b6b
      set fish_color_param 7cb5ec
      set fish_color_comment 5f819d
      set fish_color_match 9b5c2e
      set fish_color_search_match 9b5c2e
      set fish_color_operator 9b5c2e
      set fish_color_escape 9b5c2e
      set fish_color_cwd 87d441
      set fish_color_autosuggestion 5f819d
      set fish_color_user 87d441
      set fish_color_host 87d441
      set fish_color_cancel ff6b6b
      set fish_pager_color_prefix 87d441
      set fish_pager_color_completion normal
      set fish_pager_color_description 5f819d
      set fish_pager_color_progress 87d441
      set fish_pager_color_secondary normal
      
      # Set fish prompt
      function fish_prompt
        set_color 87d441
        echo -n (prompt_pwd)
        set_color normal
        echo -n " ❯ "
      end
      
      # Set fish title
      function fish_title
        echo (prompt_pwd)
      end
    '';
    
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      
      # Listing
      "ll" = "ls -la";
      "la" = "ls -A";
      "l" = "ls -CF";
      
      # Git
      "g" = "git";
      "ga" = "git add";
      "gc" = "git commit";
      "gp" = "git push";
      "gl" = "git log --oneline --graph --decorate";
      "gs" = "git status";
      "gd" = "git diff";
      "gb" = "git branch";
      "gco" = "git checkout";
      "gcb" = "git checkout -b";
      
      # Development
      "py" = "python3";
      "pip" = "pip3";
      "node" = "nodejs";
      "npm" = "npm";
      "yarn" = "yarn";
      
      # System
      "update" = "sudo nixos-rebuild switch --flake .#ubuntu";
      "update-darwin" = "darwin-rebuild switch --flake .#macbook";
      "clean" = "nix-collect-garbage -d && nix-store --optimise";
      
      # Utilities
      "c" = "clear";
      "h" = "history";
      "j" = "jobs";
      "v" = "vim";
      "n" = "nvim";
      "f" = "fzf";
      "z" = "zoxide";
    };
  };

  # Enable starship prompt
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      
      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };
      
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        style = "blue";
      };
      
      git_branch = {
        symbol = " ";
        style = "purple";
      };
      
      git_status = {
        style = "red";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?";
        stashed = "≡";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };
      
      nodejs = {
        symbol = " ";
        style = "green";
      };
      
      python = {
        symbol = " ";
        style = "yellow";
      };
      
      rust = {
        symbol = " ";
        style = "red";
      };
      
      golang = {
        symbol = " ";
        style = "cyan";
      };
    };
  };

  # Enable zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Enable fzf
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f";
    defaultOptions = [ "--height 40%" "--border" ];
    fileWidgetCommand = "fd --type f";
    fileWidgetOptions = [ "--preview 'bat --style=numbers --color=always --line-range :500 {}'" ];
  };

  # Enable bat (better cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      style = "numbers,changes,header";
    };
  };

  # Enable exa (better ls)
  programs.exa = {
    enable = true;
    enableAliases = true;
  };

  # Enable git
  programs.git = {
    enable = true;
    userName = "snowbear";
    userEmail = "snowbear@example.com";
    
    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      ca = "commit -a";
      cm = "commit -m";
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      visual = "!gitk";
      lg = "log --oneline --graph --decorate";
      lga = "log --oneline --graph --decorate --all";
    };
    
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "vim";
      core.autocrlf = if isDarwin then "input" else "input";
      color.ui = "auto";
      color.branch = "auto";
      color.diff = "auto";
      color.status = "auto";
      diff.tool = "vimdiff";
      merge.tool = "vimdiff";
      credential.helper = if isDarwin then "osxkeychain" else "cache";
    };
  };

  # Enable tmux
  programs.tmux = {
    enable = true;
    shortcut = "Space";
    baseIndex = 1;
    escapeTime = 0;
    terminal = "screen-256color";
    
    extraConfig = ''
      # Enable mouse
      set -g mouse on
      
      # Set status bar
      set -g status-style bg=colour235,fg=colour136,default
      set -g window-status-current-style bg=colour136,fg=colour235
      set -g window-status-style bg=colour235,fg=colour136
      
      # Set pane border
      set -g pane-border-style fg=colour235
      set -g pane-active-border-style fg=colour136
      
      # Set window title
      set -g set-titles on
      set -g set-titles-string '#T'
      
      # Increase scrollback buffer
      set -g history-limit 10000
      
      # Enable focus events
      set -g focus-events on
      
      # Set default shell
      set -g default-shell /run/current-system/sw/bin/fish
    '';
    
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
  };

  # Enable neovim
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    
    extraConfig = ''
      " Basic settings
      set number
      set relativenumber
      set mouse=a
      set clipboard+=unnamedplus
      set expandtab
      set shiftwidth=2
      set tabstop=2
      set softtabstop=2
      set autoindent
      set smartindent
      set ignorecase
      set smartcase
      set incsearch
      set hlsearch
      set nobackup
      set noswapfile
      set nowritebackup
      set updatetime=300
      set shortmess+=c
      set signcolumn=yes
      set termguicolors
      set background=dark
      
      " Key mappings
      let mapleader = " "
      nnoremap <leader>w :w<CR>
      nnoremap <leader>q :q<CR>
      nnoremap <leader>Q :q!<CR>
      nnoremap <leader>h :nohl<CR>
      nnoremap <leader>j :bn<CR>
      nnoremap <leader>k :bp<CR>
      nnoremap <leader>d :bd<CR>
      nnoremap <leader>f :find 
      nnoremap <leader>g :grep 
      nnoremap <leader>s :split<CR>
      nnoremap <leader>v :vsplit<CR>
      nnoremap <leader>t :tabnew<CR>
      nnoremap <leader>n :tabnext<CR>
      nnoremap <leader>p :tabprev<CR>
      
      " Colorscheme
      colorscheme default
    '';
  };

  # Enable direnv
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  # Enable gpg
  programs.gpg = {
    enable = true;
    settings = {
      default-key = "your-gpg-key-id";
      use-agent = true;
    };
  };

  # Enable ssh
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        AddKeysToAgent yes
        UseKeychain yes
        IdentityFile ~/.ssh/id_rsa
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  # Enable alacritty (terminal emulator)
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.9;
        decorations = "buttonless";
        dynamic_title = true;
        padding = {
          x = 10;
          y = 10;
        };
      };
      
      font = {
        normal = {
          family = "FiraCode Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "FiraCode Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "FiraCode Nerd Font";
          style = "Italic";
        };
        size = 12;
      };
      
      colors = {
        primary = {
          background = "0x1e1e2e";
          foreground = "0xcdd6f4";
        };
        cursor = {
          text = "0x1e1e2e";
          cursor = "0xf5c2e7";
        };
        normal = {
          black = "0x45475a";
          red = "0xf38ba8";
          green = "0xa6e3a1";
          yellow = "0xf9e2af";
          blue = "0x89b4fa";
          magenta = "0xf5c2e7";
          cyan = "0x94e2d5";
          white = "0xcdd6f4";
        };
        bright = {
          black = "0x585b70";
          red = "0xf38ba8";
          green = "0xa6e3a1";
          yellow = "0xf9e2af";
          blue = "0x89b4fa";
          magenta = "0xf5c2e7";
          cyan = "0x94e2d5";
          white = "0xf5e0dc";
        };
      };
      
      shell = {
        program = "fish";
      };
    };
  };

  # Home packages
  home.packages = with pkgs; [
    # Core utilities
    ripgrep
    fd
    tree
    htop
    jq
    curl
    wget
    
    # Development tools
    gcc
    clang
    cmake
    pkg-config
    rustup
    nodejs
    python3
    go
    
    # Network tools
    mtr
    nmap
    wireshark
    
    # Media tools
    ffmpeg
    imagemagick
    
    # Nix development
    nixpkgs-fmt
    statix
    deadnix
    
    # GUI applications (if on Linux)
  ] ++ lib.optionals isLinux [
    firefox
    vscode
    discord
    slack
    spotify
    docker
    postman
  ];

  # Services
  services = {
    # GPG agent
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentryFlavor = if isDarwin then "curses" else "gtk2";
    };
    
    # SSH agent
    ssh-agent = {
      enable = true;
    };
  } // lib.optionalAttrs isDarwin {
    # Darwin-specific services
    keychain = {
      enable = true;
      enableSshSupport = true;
      keys = [ "id_rsa" "id_ed25519" ];
    };
  };

  # XDG base directories
  xdg = {
    enable = true;
    
    userDirs = {
      enable = true;
      desktop = "\$HOME/Desktop";
      documents = "\$HOME/Documents";
      download = "\$HOME/Downloads";
      music = "\$HOME/Music";
      pictures = "\$HOME/Pictures";
      publicShare = "\$HOME/Public";
      templates = "\$HOME/Templates";
      videos = "\$HOME/Videos";
    };
  };

  # Systemd user services (Linux only)
  systemd.user.services = lib.mkIf isLinux {
    # Add custom user services here
  };

  # Systemd user timers (Linux only)
  systemd.user.timers = lib.mkIf isLinux {
    # Add custom user timers here
  };
} 
