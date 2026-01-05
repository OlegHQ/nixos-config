# Fish Shell Configuration
# Elegant prompt, smart integrations, optimized for development workflow

function _git_info
    # Skip network mounts (Samba, NFS, etc.) - they're too slow
    switch (pwd)
        case '/Volumes/*' '/mnt/*' '/net/*'
            return
    end

    # Only proceed if we are inside a git work tree
    command git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; or return

    # Try to get current branch; fallback to short commit hash
    set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    or set branch (command git rev-parse --short HEAD 2>/dev/null)
    or return

    # Determine dirty state (includes untracked)
    set -l dirty ''
    set -l git_status (command git status -s --ignore-submodules=dirty 2>/dev/null)
    if test -n "$git_status"
        set dirty '±'
    end

    set -l bold_cyan (set_color -o cyan)
    set -l normal (set_color normal)
    echo -n -s '(' $bold_cyan $branch $dirty $normal ')'
end

function fish_prompt
    set -l last_status $status

    set -l magenta (set_color brblack)
    set -l bold_cyan (set_color -o cyan)
    set -l yellow (set_color normal)
    set -l red (set_color red)
    set -l blue (set_color blue)
    set -l green (set_color green)
    set -l normal (set_color normal)

    # Current working directory in magenta
    set -l cwd $magenta(pwd | sed "s:^$HOME:~:")

    # New line before prompt
    echo

    # Virtual env in magenta background
    if set -q VIRTUAL_ENV
        echo -n -s (set_color -b magenta black) '[' (basename "$VIRTUAL_ENV") ']' $normal ' '
    end

    # Print cwd
    echo -n -s $cwd $normal

    # Show git branch and status
    set -l gi (_git_info)
    if test -n "$gi"
        echo -n -s ' · ' $gi
    end

    # Color for prompt char depends on last command’s status
    set -l prompt_color $red
    if test $last_status = 0
        set prompt_color $normal
    end

    # The prompt char
    echo
    echo -n -s $prompt_color '⟩ ' $normal
end

# ═══════════════════════════════════════════════════════════════════════════════
# Terminal Integration
# ═══════════════════════════════════════════════════════════════════════════════
if set -q GHOSTTY_RESOURCES_DIR
    set -l _ghostty_file "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
    test -f $_ghostty_file; and source $_ghostty_file
end

# ═══════════════════════════════════════════════════════════════════════════════
# Program Setup
# ═══════════════════════════════════════════════════════════════════════════════
# Vim directories
mkdir -p $HOME/.vim/{backup,swap,undo}

# Homebrew
if test -d "/opt/homebrew"
    set -gx HOMEBREW_PREFIX "/opt/homebrew"
    set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar"
    set -gx HOMEBREW_REPOSITORY "/opt/homebrew"
    fish_add_path -g "/opt/homebrew/bin" "/opt/homebrew/sbin"
    set -q MANPATH; or set MANPATH ''
    set -gx MANPATH "/opt/homebrew/share/man" $MANPATH
    set -q INFOPATH; or set INFOPATH ''
    set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH
    
    # Add Homebrew Ruby and gems to PATH for CocoaPods compatibility
    fish_add_path -g "/opt/homebrew/opt/ruby/bin"
    
    # Add gem bin directory (detect version dynamically)
    for gem_dir in /opt/homebrew/lib/ruby/gems/*/bin
        if test -d "$gem_dir"
            fish_add_path -g "$gem_dir"
            break
        end
    end
end

# ═══════════════════════════════════════════════════════════════════════════════
# Visual Configuration
# ═══════════════════════════════════════════════════════════════════════════════
# Clean startup
set --universal --erase fish_greeting
function fish_greeting; end

# Command text (e.g., ls, git, etc.)
set fish_color_command 005fd7

# Parameters/Arguments
set fish_color_param 005f87

# Paths
set fish_color_cwd 0087af

# Search Match
set fish_color_match 00afff --bold

# User input text
set fish_color_normal black

# Error messages
set fish_color_error ff0000

# Comments
set fish_color_comment 5f5f5f

# Selection in menus
set fish_color_selection black --background=87afff

# Autosuggestions
set fish_color_autosuggestion 8a8a8a

# Valid syntax (prompt text)
set fish_color_valid_path 0087af --bold

# Syntax highlighting for invalid commands
set fish_color_operator 005f87
set fish_color_escape 005fd7 --bold
set fish_color_quote 00875f
set fish_color_redirection 870000 --bold
# Directory colors
set -Ux LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

# Check if the operating system is Linux
if string match -q "Linux" (uname)
    # Set COLORTERM to truecolor
    set -x COLORTERM truecolor
end


# ═══════════════════════════════════════════════════════════════════════════════
# Path Management
# ═══════════════════════════════════════════════════════════════════════════════
# Personal development paths
fish_add_path -g $HOME/code/go/bin
fish_add_path -g $HOME/bin

# Exported variables
if isatty
    set -x GPG_TTY (tty)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Aliases & Development Hooks
# ═══════════════════════════════════════════════════════════════════════════════
# Development shortcuts
alias fnix "nix-shell --run fish"  # Quick nix-shell with fish: `fnix -p go`

type -q direnv; and direnv hook fish | source
type -q opam; and eval (opam env)
