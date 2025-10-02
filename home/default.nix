{ inputs, ... }:
{ config, lib, pkgs, ... }:

let
  fishSources = {
    "fish-fzf" = inputs."fish-fzf";
    "fish-foreign-env" = inputs."fish-foreign-env";
  };
  tmuxSources = {
    "tmux-pain-control" = inputs."tmux-pain-control";
    "tmux-catppuccin" = inputs."tmux-catppuccin";
  };
  helixImport = import ./helix.nix;
  helix = helixImport { inherit pkgs; };
  # Helper: install kubectl completions for Fish
  installKubectlCompletion = pkgs.writeShellScriptBin "install-kubectl-completion" ''
    FISH_CONFIG_DIR="$HOME/.config/fish"
    COMPLETIONS_DIR="$FISH_CONFIG_DIR/completions"
    REPO_DIR="$FISH_CONFIG_DIR/fish-kubectl-completions"
    COMPLETION_FILE="$COMPLETIONS_DIR/kubectl.fish"

    mkdir -p "$COMPLETIONS_DIR"
    if [ ! -d "$REPO_DIR" ]; then
      git clone https://github.com/evanlucas/fish-kubectl-completions "$REPO_DIR"
    fi
    if [ ! -L "$COMPLETION_FILE" ]; then
      ln -s ../fish-kubectl-completions/completions/kubectl.fish "$COMPLETION_FILE"
    fi
  '';

  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # Shared Git aliases used by bash and fish
  gitAliases = {
    ga = "git add";
    gc = "git commit";
    gco = "git checkout";
    gcp = "git cherry-pick";
    gdiff = "git diff";
    gl = "git prettylog";
    gp = "git push";
    gs = "git status";
    gt = "git tag";
  };

  # `man` pager via bat (see: https://github.com/sharkdp/bat/issues/1145)
  manpager = (pkgs.writeShellScriptBin "manpager" (if isDarwin then ''
    sh -c 'col -bx | bat -l man -p'
  '' else ''
    cat "$1" | col -bx | bat --language man --style plain
  ''));

  # Script to dump terminal/tmux scroll history to file and open in neovim
  dumptty = pkgs.writeShellScriptBin "dumptty" ''
    # Generate timestamped filename
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    TMPFILE="/tmp/terminal_dump_$TIMESTAMP.txt"
    
    if [ -n "$TMUX" ]; then
        # We're in tmux - capture the pane history
        echo "Dumping tmux pane history to $TMPFILE"
        tmux capture-pane -pS - > "$TMPFILE"
    else
        # We're in a regular terminal - scrollback capture is not possible
        echo "❌ dumptty only works inside tmux!"
        echo "Regular terminals don't expose their scrollback buffer to programs."
        echo ""
        echo "💡 Suggestions:"
        echo "  • Use tmux for terminal session management"
        echo "  • Or manually copy/paste the content you need"
        exit 1
    fi
    
    echo "Saved terminal dump to: $TMPFILE"
    
    # Open in neovim and scroll to bottom
    nvim '+normal G' "$TMPFILE"
  '';


in {
  # HM state version
  home.stateVersion = "18.09";

  xdg.enable = true;

  # ═══════════════════════════════════════════════════════════════════════════════
  # Package Management
  # ═══════════════════════════════════════════════════════════════════════════════
  
  # Core development tools and utilities
  # Project-specific dependencies managed via direnv + flakes
  home.packages = [
    pkgs.bat
    pkgs.fd
    pkgs.fzf
    pkgs.htop
    pkgs.jq
    pkgs.ripgrep
    pkgs.tree
    pkgs.watch
    pkgs.tree-sitter
    pkgs.nodePackages_latest.typescript-language-server
    pkgs.opam
    pkgs.lazygit

    pkgs.clang-tools

    pkgs.fswatch
    pkgs.watchman

    pkgs.direnv
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.awscli2

    pkgs.python3
    pkgs.nodejs_24

    pkgs.uv
    pkgs.claude-code
    pkgs.codex

    dumptty
  ] ++ (lib.optionals isLinux [
    # Linux-specific packages
    pkgs.util-linux
    pkgs.gcc
    pkgs.bzip2
    pkgs.gmp
    pkgs.pkg-config
    # Clipboard tools 
    pkgs.xclip
    pkgs.xsel
  ]) ++ helix.packages;

  # ═══════════════════════════════════════════════════════════════════════════════
  # Environment & Configuration Files
  # ═══════════════════════════════════════════════════════════════════════════════
  home.activation.installKubectlCompletion =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${installKubectlCompletion}/bin/install-kubectl-completion
    '';

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
    GEMINI_CLI_SYSTEM_DEFAULTS_PATH = "${config.xdg.configHome}/gemini/settings.json";
  };

  home.file.".inputrc".source = ./configs/inputrc;
  # Silence "Last login:" on macOS and other login shells
  home.file.".hushlogin".text = "";
  

  xdg.configFile."ghostty/config".text = builtins.readFile ./configs/ghostty.config;
  xdg.configFile."helix/languages.toml".text = helix.languages;
  xdg.configFile."helix/config.toml".text = helix.config;
  
  # Claude Code settings
  home.file.".claude/settings.json".source = ./configs/claude-settings.json;
  
  # Gemini CLI settings
  xdg.configFile."gemini/settings.json".source = ./configs/gemini-settings.json;
  
  # usql configuration with light theme
  home.file.".usqlrc".source = ./configs/usqlrc;

  # ═══════════════════════════════════════════════════════════════════════════════
  # Program Configuration
  # ═══════════════════════════════════════════════════════════════════════════════

  programs.gpg.enable = !isDarwin;

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [ "ignoredups" "ignorespace" ];

    shellAliases = gitAliases;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = lib.strings.concatStrings
      (lib.strings.intersperse "\n" ([
        (builtins.readFile ./configs/config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
        "if type -q npm; npm set prefix ~/.npm-global; set -Ux fish_user_paths $HOME/.npm-global/bin $fish_user_paths; end"
      ]));

    shellAliases = gitAliases;

    plugins = map (n: {
      name = n;
      src = fishSources.${n};
    }) [ "fish-fzf" "fish-foreign-env" ];
  };

  programs.git = {
    enable = true;
    userName = "Oleg Pustovit";
    userEmail = "oleg@nexo.sh";
    extraConfig = {
      core.editor = "nvim";
      push.autoSetupRemote = true;
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    shortcut = "a";
    secureSocket = false;
    
    # Disable Home Manager clipboard handling - we'll do it ourselves
    disableConfirmationPrompt = true;

    extraConfig = ''
      set -ga terminal-overrides ",xterm-256color:Tc"
      set -s set-clipboard on
      set -g allow-passthrough

      # Configure the catppuccin plugin
      set -g @catppuccin_flavor "latte"
      set -g @catppuccin_window_status_style "rounded"

      bind -n C-k send-keys "clear"\; send-keys "Enter"

      run-shell ${tmuxSources."tmux-pain-control"}/pain_control.tmux
      run-shell ${tmuxSources."tmux-catppuccin"}/catppuccin.tmux
      set -sg escape-time 0
      setw -g mouse on
    '';
  };

  programs.neovim = {
    enable = true;

    package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;

    withPython3 = true;
    viAlias = true;

    plugins = with pkgs; [
      customVim.nvim-hotpot
      pkgs.vimPlugins.plenary-nvim
      pkgs.vimPlugins.telescope-nvim
      customVim.nvim-lspconfig
      customVim.nvim-comment
      pkgs.vimPlugins.nvim-cmp
      pkgs.vimPlugins.cmp-buffer
      pkgs.vimPlugins.cmp-nvim-lsp
      customVim.nvim-gitsigns
      customVim.nvim-conform
      pkgs.vimPlugins.nvim-treesitter.withAllGrammars
      vimPlugins.catppuccin-nvim
      customVim.nvim-lualine
      vimPlugins.nvim-autopairs
      vimPlugins.cmp-path
      vimPlugins.bufferline-nvim
      vimPlugins.hop-nvim
      customVim.nvim-lsplines
      vimPlugins.indent-blankline-nvim
    ];
  };
}

