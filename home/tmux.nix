# Tmux configuration
{ inputs }:
{ config, lib, pkgs, ... }:

let
  theme = import ./theme.nix;
  p = theme.palette;

  tmuxSources = {
    "tmux-pain-control" = inputs."tmux-pain-control";
    "tmux-catppuccin" = inputs."tmux-catppuccin";
  };

  # Smart clipboard yank — native clipboard locally, OSC52 for remote
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

    if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ] || [ -n "$MOSH_SERVER_PID" ]; then
      copy_osc52
      exit 0
    fi

    if command -v pbcopy &>/dev/null; then
      printf '%s' "$input" | pbcopy
      exit 0
    fi

    if [ -n "$DISPLAY" ]; then
      if command -v xclip &>/dev/null; then
        printf '%s' "$input" | xclip -selection clipboard
        exit 0
      fi
    fi

    if [ -n "$WAYLAND_DISPLAY" ]; then
      if command -v wl-copy &>/dev/null; then
        printf '%s' "$input" | wl-copy
        exit 0
      fi
    fi

    copy_osc52
  '';

  # Generated from palette — single source of truth
  tmuxOC1Styles = ''
    # OpenCode OC-1 Dark theme for tmux
    set -g status-style "bg=#${p.mantle},fg=#${p.text}"
    set -g status-left "#[bg=#${p.primary},fg=#${p.base},bold] #S #[bg=#${p.mantle},fg=#${p.primary}]"
    set -g status-right "#[fg=#${p.subtext0}]%Y-%m-%d #[fg=#${p.text}]%H:%M "
    set -g status-left-length 50
    set -g status-right-length 50

    set -g window-status-format "#[fg=#${p.subtext0}] #I:#W "
    set -g window-status-current-format "#[bg=#${p.surface1},fg=#${p.blue},bold] #I:#W #[bg=#${p.mantle}]"
    set -g window-status-separator ""

    set -g pane-border-style "fg=#${p.surface1}"
    set -g pane-active-border-style "fg=#${p.primary}"

    set -g message-style "bg=#${p.surface1},fg=#${p.subtext1}"
    set -g message-command-style "bg=#${p.surface1},fg=#${p.subtext1}"
    set -g mode-style "bg=#${p.surface1},fg=#${p.subtext1}"
  '';

in {
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    shortcut = "a";
    secureSocket = false;
    disableConfirmationPrompt = true;
    mouse = true;
    escapeTime = 0;

    extraConfig = ''
      set -as terminal-features ",xterm*:RGB,tmux*:RGB,screen*:RGB,foot*:RGB,alacritty*:RGB,kitty*:RGB,wezterm*:RGB,ghostty*:RGB"
      set -ga terminal-overrides ",xterm*:Tc,tmux*:Tc,screen*:Tc,foot*:Tc,alacritty*:Tc,kitty*:Tc,wezterm*:Tc,ghostty*:Tc"
      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[ q'
      set-environment -g COLORTERM truecolor
      set -g allow-passthrough on
      set -s set-clipboard off

      bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"

      bind -n C-k send-keys "clear" Enter

      run-shell ${tmuxSources."tmux-pain-control"}/pain_control.tmux
    '' + (if theme.themeFamily == "opencode" then tmuxOC1Styles else ''
      set -g @catppuccin_flavor "${theme.tmuxCatppuccinFlavor}"
      set -g @catppuccin_window_status_style "rounded"
      run-shell ${tmuxSources."tmux-catppuccin"}/catppuccin.tmux
    '');
  };
}
