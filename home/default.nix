{ inputs, ... }:
{ config, lib, pkgs, ... }:

let
  fishSources = {
    "fish-fzf" = inputs."fish-fzf";
    "fish-foreign-env" = inputs."fish-foreign-env";
    "fish-async-prompt" = inputs."fish-async-prompt";
  };
  tmuxSources = {
    "tmux-pain-control" = inputs."tmux-pain-control";
    "tmux-catppuccin" = inputs."tmux-catppuccin";
  };
  # Smart clipboard yank script - uses native clipboard locally, OSC52 for remote
  yank = pkgs.writeShellScriptBin "yank" ''
    input=$(cat)

    copy_osc52() {
      encoded=$(printf '%s' "$input" | base64 | tr -d '\n')
      if [ -n "$TMUX" ]; then
        tty=$(tmux display-message -p '#{client_tty}')
        printf '\033]52;c;%s\a' "$encoded" > "$tty"
      else
        printf '\033]52;c;%s\a' "$encoded"
      fi
    }

    # Remote session (SSH or mosh): use OSC52 to pass through to local clipboard
    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ] || [ -n "$MOSH_SERVER_PID" ]; then
      copy_osc52
      exit 0
    fi

    # Mac: use pbcopy (only for local sessions)
    if command -v pbcopy &>/dev/null; then
      printf '%s' "$input" | pbcopy
      exit 0
    fi

    # Local Linux with X11: use xclip
    if [ -n "$DISPLAY" ]; then
      if command -v xclip &>/dev/null; then
        printf '%s' "$input" | xclip -selection clipboard
        exit 0
      fi
    fi

    # Local Linux with Wayland: use wl-copy
    if [ -n "$WAYLAND_DISPLAY" ]; then
      if command -v wl-copy &>/dev/null; then
        printf '%s' "$input" | wl-copy
        exit 0
      fi
    fi

    # Fallback: OSC52
    copy_osc52
  '';

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
        echo "dumptty only works inside tmux!"
        echo "Regular terminals don't expose their scrollback buffer to programs."
        echo ""
        echo "Suggestions:"
        echo "  - Use tmux for terminal session management"
        echo "  - Or manually copy/paste the content you need"
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
    pkgs.lazygit
    pkgs.zoxide
    pkgs.gh

    pkgs.clang-tools

    pkgs.fswatch
    pkgs.watchman

    pkgs.direnv
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.awscli2

    pkgs.glow

    pkgs.python3
    pkgs.nodejs_24

    pkgs.dotnet-sdk

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
    # .NET configuration
    DOTNET_ROOT = "${pkgs.dotnet-sdk}/share/dotnet";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
  };

  home.file.".inputrc".source = ./configs/inputrc;
  # Silence "Last login:" on macOS and other login shells
  home.file.".hushlogin".text = "";
  


  xdg.configFile."ghostty/config".text = builtins.readFile ./configs/ghostty.config;
  xdg.configFile."helix/languages.toml".text = helix.languages;
  xdg.configFile."helix/config.toml".text = helix.config;
  
  # Gemini CLI settings
  xdg.configFile."gemini/settings.json".source = ./configs/gemini-settings.json;

  # Zed editor settings
  xdg.configFile."zed/settings.json".source = ./configs/zed-settings.json;
  xdg.configFile."zed/keymap.json".source = ./configs/zed-keymap.json;

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

    shellAliases = gitAliases // {
      ccc = "claude --dangerously-skip-permissions";
    };
  };

  # Zoxide - smart directory jumping
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd" "cd" ];
  };

  programs.fish = {
    enable = true;

    # One-time setup (login shells only)
    loginShellInit = ''
      mkdir -p $HOME/.vim/{backup,swap,undo}
    '';

    interactiveShellInit = lib.strings.concatStrings
      (lib.strings.intersperse "\n" ([
        (builtins.readFile ./configs/config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
        "command -sq npm; and npm set prefix ~/.npm-global 2>/dev/null; and fish_add_path -g $HOME/.npm-global/bin"
        "fish_add_path $HOME/.dotnet/tools"
      ]));

    # Aliases (don't expand inline)
    shellAliases = gitAliases // {
      lg = "lazygit";
      l = "ls -la";
      ll = "ls -l";
      k = "kubectl";
      kns = "kubectl config set-context --current --namespace";
      ccc = "claude --dangerously-skip-permissions";
    };

    # Abbreviations for directory navigation (expand inline)
    shellAbbrs = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
    };

    # Functions as separate files (properly overrides defaults)
    functions = {
      # Detect slow network mounts (NAS, Samba, NFS)
      _is_slow_fs = ''
        set -l real_path (pwd -P)
        string match -q '/Volumes/*' -- $real_path
        or string match -q '/mnt/*' -- $real_path
        or string match -q '/net/*' -- $real_path
      '';

      # Git info - skips slow mounts
      _git_info = ''
        _is_slow_fs; and return

        set -l git_dir (command git rev-parse --git-dir 2>/dev/null)
        test -z "$git_dir"; and return

        set -l branch
        if test -f "$git_dir/HEAD"
            read -l head < "$git_dir/HEAD"
            set branch (string replace 'ref: refs/heads/' ''' -- "$head")
            string match -q 'ref:*' -- "$branch"
            and set branch (command git rev-parse --short HEAD 2>/dev/null)
        end
        test -z "$branch"; and return

        set -l dirty
        not command git diff --quiet HEAD 2>/dev/null
        and set dirty '+'

        echo -n (set_color 1e66f5)"($branch$dirty)"(set_color normal)
      '';

      # Command duration - only show for >1s
      _cmd_duration = ''
        test $CMD_DURATION -lt 1000; and return
        set -l s (math "floor($CMD_DURATION / 1000)")
        set -l m (math "floor($s / 60)")
        if test $m -gt 0
            set -l rem (math "$s % 60")
            echo -n (set_color 8c8fa1)" "$m"m"$rem"s"(set_color normal)
        else
            echo -n (set_color 8c8fa1)" "$s"s"(set_color normal)
        end
      '';

      fish_prompt = builtins.readFile ./configs/fish_prompt.fish;
      fish_right_prompt = ''
        set -l last_status $status
        test $last_status -ne 0
        and echo -n (set_color d20f39)"["$last_status"]"(set_color normal)
      '';
      fish_greeting = "";
    };

    plugins = map (n: {
      name = n;
      src = fishSources.${n};
    }) [ "fish-fzf" "fish-foreign-env" "fish-async-prompt" ];
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Oleg Pustovit";
      user.email = "oleg@nexo.sh";
      core.editor = "nvim";
      push.autoSetupRemote = true;
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    shortcut = "a";
    secureSocket = false;
    disableConfirmationPrompt = true;
    mouse = true;
    escapeTime = 0;

    extraConfig = ''
      set -ga terminal-overrides ",xterm-256color:Tc"
      set -g allow-passthrough on
      set -s set-clipboard off

      # Catppuccin theme
      set -g @catppuccin_flavor "latte"
      set -g @catppuccin_window_status_style "rounded"

      # Copy bindings using smart yank
      bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"

      bind -n C-k send-keys "clear" Enter

      # Load Nix plugins
      run-shell ${tmuxSources."tmux-pain-control"}/pain_control.tmux
      run-shell ${tmuxSources."tmux-catppuccin"}/catppuccin.tmux
    '';
  };

  programs.neovim = {
    enable = true;

    withPython3 = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [
      hotpot-nvim
      plenary-nvim
      telescope-nvim
      nvim-lspconfig
      comment-nvim
      nvim-cmp
      cmp-buffer
      cmp-nvim-lsp
      gitsigns-nvim
      conform-nvim
      nvim-treesitter.withAllGrammars
      catppuccin-nvim
      lualine-nvim
      nvim-autopairs
      cmp-path
      bufferline-nvim
      hop-nvim
      lsp_lines-nvim
      vim-visual-multi
      indent-blankline-nvim
    ];
  };
}

