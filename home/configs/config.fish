# Fish Shell Configuration
# Ultra-fast async prompt with Catppuccin Latte theme

# ═══════════════════════════════════════════════════════════════════════════════
# Catppuccin Latte Theme
# ═══════════════════════════════════════════════════════════════════════════════

set -g fish_color_normal 4c4f69
set -g fish_color_command 1e66f5
set -g fish_color_param dd7878
set -g fish_color_keyword d20f39
set -g fish_color_quote 40a02b
set -g fish_color_redirection ea76cb
set -g fish_color_end fe640b
set -g fish_color_comment 8c8fa1
set -g fish_color_error d20f39
set -g fish_color_selection --background=ccd0da
set -g fish_color_search_match --background=ccd0da
set -g fish_color_operator ea76cb
set -g fish_color_escape e64553
set -g fish_color_autosuggestion 9ca0b0
set -g fish_color_cancel d20f39
set -g fish_color_cwd df8e1d
set -g fish_color_user 179299
set -g fish_color_host 1e66f5
set -g fish_color_status d20f39
set -g fish_color_valid_path --underline
set -g fish_pager_color_progress 9ca0b0
set -g fish_pager_color_prefix ea76cb
set -g fish_pager_color_completion 4c4f69
set -g fish_pager_color_description 8c8fa1

# ═══════════════════════════════════════════════════════════════════════════════
# FZF Configuration (Catppuccin Latte)
# ═══════════════════════════════════════════════════════════════════════════════

set -gx FZF_DEFAULT_OPTS "\
--height 40% --layout=reverse --border \
--color=bg+:#ccd0da,bg:#eff1f5,spinner:#1e66f5,hl:#d20f39 \
--color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#1e66f5 \
--color=marker:#1e66f5,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"

# Use fd for faster file/directory search
if command -sq fd
    set -gx FZF_CTRL_T_COMMAND "fd --type f --hidden --follow --exclude .git"
    set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --follow --exclude .git"
end

# ═══════════════════════════════════════════════════════════════════════════════
# Keybindings
# ═══════════════════════════════════════════════════════════════════════════════

function fish_user_key_bindings
    # Ctrl+Z to toggle background/foreground
    bind \cz 'fg 2>/dev/null; commandline -f repaint'

    # Alt+. to insert last argument (like bash)
    bind \e. history-token-search-backward
end

# ═══════════════════════════════════════════════════════════════════════════════
# Terminal Integration
# ═══════════════════════════════════════════════════════════════════════════════

if set -q GHOSTTY_RESOURCES_DIR
    set -l _ghostty_file "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
    test -f $_ghostty_file; and source $_ghostty_file
end

# Terminal title
function fish_title
    echo (prompt_pwd): (status current-command)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Environment Setup (Guarded for Performance)
# ═══════════════════════════════════════════════════════════════════════════════

# Homebrew (macOS) - only initialize once per session
if not set -q __homebrew_initialized; and test -d "/opt/homebrew"
    set -gx HOMEBREW_PREFIX "/opt/homebrew"
    set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar"
    set -gx HOMEBREW_REPOSITORY "/opt/homebrew"
    fish_add_path -g "/opt/homebrew/bin" "/opt/homebrew/sbin"
    set -q MANPATH; or set MANPATH ''
    set -gx MANPATH "/opt/homebrew/share/man" $MANPATH
    set -q INFOPATH; or set INFOPATH ''
    set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH

    # Ruby and gems for CocoaPods
    fish_add_path -g "/opt/homebrew/opt/ruby/bin"
    for gem_dir in /opt/homebrew/lib/ruby/gems/*/bin
        test -d "$gem_dir"; and fish_add_path -g "$gem_dir"; and break
    end
    set -g __homebrew_initialized 1
end

# Personal paths
fish_add_path -g $HOME/code/go/bin $HOME/bin

# GPG TTY for interactive sessions
isatty; and set -x GPG_TTY (tty)

# Linux truecolor support
string match -q "Linux" (uname); and set -x COLORTERM truecolor

# Directory colors
set -Ux LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

# ═══════════════════════════════════════════════════════════════════════════════
# Direnv Integration (Skip Slow Mounts)
# ═══════════════════════════════════════════════════════════════════════════════

if command -sq direnv
    direnv hook fish | source
    functions -c __direnv_export_eval __direnv_export_eval_original
    function __direnv_export_eval --on-event fish_prompt
        _is_slow_fs; and return
        __direnv_export_eval_original
    end
end

# ═══════════════════════════════════════════════════════════════════════════════
# Lazy-Loaded Tools (Performance Optimization)
# ═══════════════════════════════════════════════════════════════════════════════

# opam - only load when first used
function opam --wraps=opam
    functions -e opam
    command -sq opam; and eval (command opam env)
    command opam $argv
end

# ═══════════════════════════════════════════════════════════════════════════════
# Shortcuts
# ═══════════════════════════════════════════════════════════════════════════════

alias fnix "nix-shell --run fish"
