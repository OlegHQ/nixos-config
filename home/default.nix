{ inputs, ... }:
{ config, lib, pkgs, ... }:

let
  themeMode = "dark"; # "dark" or "light" (global)
  themeFamily = "opencode"; # "catppuccin" or "opencode"

  catppuccin = {
    latte = {
      lavender = "7287fd";
      blue = "1e66f5";
      sapphire = "209fb5";
      teal = "179299";
      mauve = "8839ef";
      red = "d20f39";
      flamingo = "dd7878";
      pink = "ea76cb";
      peach = "fe640b";
      yellow = "df8e1d";
      green = "40a02b";
      overlay2 = "7c7f93";
      overlay1 = "8c8fa1";
      overlay0 = "9ca0b0";
      surface0 = "ccd0da";
      base = "eff1f5";
      text = "4c4f69";
    };

    macchiato = {
      lavender = "b7bdf8";
      blue = "8aadf4";
      sapphire = "7dc4e4";
      teal = "8bd5ca";
      mauve = "c6a0f6";
      red = "ed8796";
      flamingo = "f0c6c6";
      pink = "f5bde6";
      peach = "f5a97f";
      yellow = "eed49f";
      green = "a6da95";
      overlay2 = "939ab7";
      overlay1 = "8087a2";
      overlay0 = "6e738d";
      surface0 = "363a4f";
      base = "24273a";
      text = "cad3f5";
    };
  };

  opencode_oc1 = {
    dark = {
      # Backgrounds
      base = "131010";
      mantle = "151313";
      crust = "1c1717";
      surface0 = "191515";
      surface1 = "252121";
      surface2 = "2d2828";

      # Text (blended from alpha)
      text = "b5b0b0";
      subtext1 = "efeaea";
      subtext0 = "706a6a";

      # Overlays
      overlay0 = "4b4646";
      overlay1 = "645f5f";
      overlay2 = "716c6b";

      # Catppuccin-compatible aliases
      blue = "89b5ff";
      red = "fc533a";
      green = "12c905";
      yellow = "fcd53a";
      pink = "ff9ae2";
      mauve = "9d7cd8";
      peach = "fab283";
      teal = "00ceb9";
      lavender = "edb2f1";
      flamingo = "ffba92";
      rosewater = "f1ecec";
      sapphire = "56b6c2";
      sky = "93e9f6";
      maroon = "ff917b";

      # Semantic
      primary = "fab283";
      success = "12c905";
      warning = "fcd53a";
      error = "fc533a";
      info = "edb2f1";
      interactive = "89b5ff";

      # Syntax
      string = "00ceb9";
      primitive = "ffba92";
      property = "ff9ae2";
      type = "ecf58c";
      constant = "93e9f6";
    };
  };

  palette =
    if themeFamily == "opencode" then
      (if themeMode == "dark" then opencode_oc1.dark else opencode_oc1.dark)
    else
      (if themeMode == "dark" then catppuccin.macchiato else catppuccin.latte);

  fishTheme = ''
    # Fish theme (generated from themeFamily: ${themeFamily}, mode: ${themeMode})
    set -g fish_color_normal ${palette.text}
    set -g fish_color_command ${palette.blue}
    set -g fish_color_param ${palette.flamingo}
    set -g fish_color_keyword ${palette.red}
    set -g fish_color_quote ${palette.green}
    set -g fish_color_redirection ${palette.pink}
    set -g fish_color_end ${palette.peach}
    set -g fish_color_comment ${palette.overlay2}
    set -g fish_color_error ${palette.red}
    set -g fish_color_selection --background=${palette.surface0}
    set -g fish_color_search_match --background=${palette.surface0}
    set -g fish_color_operator ${palette.pink}
    set -g fish_color_escape ${palette.red}
    set -g fish_color_autosuggestion ${palette.overlay1}
    set -g fish_color_cancel ${palette.red}
    set -g fish_color_cwd ${palette.yellow}
    set -g fish_color_user ${palette.teal}
    set -g fish_color_host ${palette.blue}
    set -g fish_color_status ${palette.red}
    set -g fish_color_valid_path --underline

    set -g fish_pager_color_progress ${palette.overlay1}
    set -g fish_pager_color_prefix ${palette.pink}
    set -g fish_pager_color_completion ${palette.text}
    set -g fish_pager_color_description ${palette.overlay2}

    # FZF colors
    set -gx FZF_DEFAULT_OPTS "\\
    --height 40% --layout=reverse --border \\
    --color=bg+:#${palette.surface0},bg:#${palette.base},spinner:#${palette.blue},hl:#${palette.red} \\
    --color=fg:#${palette.text},header:#${palette.red},info:#${palette.mauve},pointer:#${palette.blue} \\
    --color=marker:#${palette.blue},fg+:#${palette.text},prompt:#${palette.mauve},hl+:#${palette.red}"
  '';

  fishPrompt = ''
    # Main prompt - minimal, stylish, informative
    # Layout:
    #   user@host ~/projects/repo · (main+) 3s
    #   ⟩

    set -l last_status $status

    # Theme colors (generated from themeFamily: ${themeFamily})
    set -l ctp_lavender ${palette.lavender}
    set -l ctp_blue ${palette.blue}
    set -l ctp_sapphire ${palette.sapphire}
    set -l ctp_teal ${palette.teal}
    set -l ctp_mauve ${palette.mauve}
    set -l ctp_red ${palette.red}
    set -l ctp_overlay ${palette.overlay1}

    # Blank line before prompt
    echo

    # Virtual env indicator
    if set -q VIRTUAL_ENV
        echo -n (set_color -b $ctp_mauve white)" "(basename $VIRTUAL_ENV)" "(set_color normal)" "
    end

    # user@host (muted)
    echo -n (set_color $ctp_overlay)(whoami)(set_color $ctp_teal)"@"(set_color $ctp_overlay)(prompt_hostname)(set_color normal)" "

    # Working directory (Catppuccin sapphire)
    echo -n (set_color $ctp_sapphire)(prompt_pwd --full-length-dirs 2)(set_color normal)

    # Git info
    set -l gi (_git_info)
    test -n "$gi"; and echo -n (set_color $ctp_overlay)" · "(set_color normal)$gi

    # Command duration
    _cmd_duration

    # Newline and prompt char
    echo

    # Prompt char: red on error, lavender on success
    if test $last_status -ne 0
        echo -n (set_color $ctp_red)"⟩"(set_color normal)" "
    else
        echo -n (set_color $ctp_lavender)"⟩"(set_color normal)" "
    end
  '';

  ghosttyTheme =
    if themeFamily == "opencode" then
      "OpenCode-OC1-Dark"
    else if themeMode == "dark" then
      "Catppuccin Macchiato"
    else
      "Tinacious Design Light";

  # Ghostty custom theme file content for OpenCode OC-1 Dark
  ghosttyOC1Theme = ''
    background = 131010
    foreground = b5b0b0
    cursor-color = fab283
    selection-background = 252121
    selection-foreground = efeaea

    # Normal colors (0-7)
    palette = 0=#131010
    palette = 1=#fc533a
    palette = 2=#12c905
    palette = 3=#fcd53a
    palette = 4=#89b5ff
    palette = 5=#9d7cd8
    palette = 6=#00ceb9
    palette = 7=#b5b0b0

    # Bright colors (8-15)
    palette = 8=#706a6a
    palette = 9=#ff917b
    palette = 10=#4ee541
    palette = 11=#fce06a
    palette = 12=#a8c8ff
    palette = 13=#b99ce8
    palette = 14=#3ddbc8
    palette = 15=#efeaea
  '';

  ghosttyConfig = ''
    theme = "${ghosttyTheme}"
    font-family = "PragmataPro Liga"
    cursor-style = block
    shell-integration-features = no-cursor
    keybind = "ctrl+l=unbind"

    # Enable OSC52 clipboard support for SSH/mosh
    clipboard-read = "allow"
    clipboard-write = "allow"
    clipboard-paste-protection = false
    clipboard-paste-bracketed-safe = false
  '';

  tmuxCatppuccinFlavor = if themeMode == "dark" then "macchiato" else "latte";

  # OpenCode OC-1 tmux inline styles
  tmuxOC1Styles = ''
    # OpenCode OC-1 Dark theme for tmux
    set -g status-style "bg=#151313,fg=#b5b0b0"
    set -g status-left "#[bg=#fab283,fg=#131010,bold] #S #[bg=#151313,fg=#fab283]"
    set -g status-right "#[fg=#706a6a]%Y-%m-%d #[fg=#b5b0b0]%H:%M "
    set -g status-left-length 50
    set -g status-right-length 50

    # Window status
    set -g window-status-format "#[fg=#706a6a] #I:#W "
    set -g window-status-current-format "#[bg=#252121,fg=#89b5ff,bold] #I:#W #[bg=#151313]"
    set -g window-status-separator ""

    # Pane borders
    set -g pane-border-style "fg=#252121"
    set -g pane-active-border-style "fg=#fab283"

    # Message style
    set -g message-style "bg=#252121,fg=#efeaea"
    set -g message-command-style "bg=#252121,fg=#efeaea"

    # Mode style (copy mode highlight)
    set -g mode-style "bg=#252121,fg=#efeaea"
  '';

  # Helix OpenCode OC-1 Dark theme
  helixOC1Theme = ''
    # OpenCode OC-1 Dark Theme for Helix
    # Syntax highlighting
    "attribute" = "type"
    "type" = "type"
    "type.enum.variant" = "teal"
    "constructor" = "constant"
    "constant" = "constant"
    "constant.character" = "teal"
    "constant.character.escape" = "pink"
    "string" = "string"
    "string.regexp" = "pink"
    "string.special" = "blue"
    "string.special.symbol" = "red"
    "comment" = { fg = "comment", modifiers = ["italic"] }
    "variable" = "text"
    "variable.parameter" = { fg = "primitive", modifiers = ["italic"] }
    "variable.builtin" = "red"
    "variable.other.member" = "blue"
    "label" = "sapphire"
    "punctuation" = "overlay2"
    "punctuation.special" = "sky"
    "keyword" = "info"
    "keyword.control.conditional" = { fg = "info", modifiers = ["italic"] }
    "operator" = "constant"
    "function" = "interactive"
    "function.macro" = "info"
    "tag" = "interactive"
    "namespace" = { fg = "type", modifiers = ["italic"] }
    "special" = "interactive"

    # Markup
    "markup.heading.1" = "error"
    "markup.heading.2" = "primary"
    "markup.heading.3" = "warning"
    "markup.heading.4" = "success"
    "markup.heading.5" = "sapphire"
    "markup.heading.6" = "lavender"
    "markup.list" = "teal"
    "markup.list.unchecked" = "overlay2"
    "markup.list.checked" = "success"
    "markup.bold" = { fg = "error", modifiers = ["bold"] }
    "markup.italic" = { fg = "error", modifiers = ["italic"] }
    "markup.link.url" = { fg = "interactive", modifiers = ["italic", "underlined"] }
    "markup.link.text" = "lavender"
    "markup.link.label" = "sapphire"
    "markup.raw" = "success"
    "markup.quote" = "pink"

    # Diff
    "diff.plus" = "success"
    "diff.minus" = "error"
    "diff.delta" = "interactive"

    # UI
    "ui.background" = { fg = "text", bg = "base" }
    "ui.linenr" = { fg = "surface1" }
    "ui.linenr.selected" = { fg = "info" }
    "ui.statusline" = { fg = "subtext1", bg = "mantle" }
    "ui.statusline.inactive" = { fg = "surface2", bg = "mantle" }
    "ui.statusline.normal" = { fg = "base", bg = "rosewater", modifiers = ["bold"] }
    "ui.statusline.insert" = { fg = "base", bg = "success", modifiers = ["bold"] }
    "ui.statusline.select" = { fg = "base", bg = "info", modifiers = ["bold"] }
    "ui.popup" = { fg = "text", bg = "surface0" }
    "ui.window" = { fg = "crust" }
    "ui.help" = { fg = "overlay2", bg = "surface0" }
    "ui.bufferline" = { fg = "subtext0", bg = "mantle" }
    "ui.bufferline.active" = { fg = "info", bg = "base", underline = { color = "info", style = "line" } }
    "ui.bufferline.background" = { bg = "crust" }
    "ui.text" = "text"
    "ui.text.focus" = { fg = "text", bg = "surface0", modifiers = ["bold"] }
    "ui.text.inactive" = { fg = "overlay1" }
    "ui.text.directory" = { fg = "interactive" }
    "ui.virtual" = "overlay0"
    "ui.virtual.ruler" = { bg = "surface0" }
    "ui.virtual.indent-guide" = "surface0"
    "ui.virtual.inlay-hint" = { fg = "surface1", bg = "mantle" }
    "ui.virtual.jump-label" = { fg = "rosewater", modifiers = ["bold"] }
    "ui.selection" = { bg = "surface1" }
    "ui.cursor" = { fg = "base", bg = "secondary_cursor" }
    "ui.cursor.primary" = { fg = "base", bg = "primary" }
    "ui.cursor.match" = { fg = "primary", modifiers = ["bold"] }
    "ui.cursor.primary.normal" = { fg = "base", bg = "rosewater" }
    "ui.cursor.primary.insert" = { fg = "base", bg = "success" }
    "ui.cursor.primary.select" = { fg = "base", bg = "info" }
    "ui.cursor.normal" = { fg = "base", bg = "secondary_cursor_normal" }
    "ui.cursor.insert" = { fg = "base", bg = "secondary_cursor_insert" }
    "ui.cursor.select" = { fg = "base", bg = "secondary_cursor_select" }
    "ui.cursorline.primary" = { bg = "cursorline" }
    "ui.highlight" = { bg = "surface1", modifiers = ["bold"] }
    "ui.menu" = { fg = "overlay2", bg = "surface0" }
    "ui.menu.selected" = { fg = "text", bg = "surface1", modifiers = ["bold"] }

    # Diagnostics
    "diagnostic.error" = { underline = { color = "error", style = "curl" } }
    "diagnostic.warning" = { underline = { color = "warning", style = "curl" } }
    "diagnostic.info" = { underline = { color = "constant", style = "curl" } }
    "diagnostic.hint" = { underline = { color = "string", style = "curl" } }
    "diagnostic.unnecessary" = { modifiers = ["dim"] }

    error = "error"
    warning = "warning"
    info = "sky"
    hint = "teal"

    [palette]
    # Backgrounds
    base = "#131010"
    mantle = "#151313"
    crust = "#1c1717"
    surface0 = "#191515"
    surface1 = "#252121"
    surface2 = "#2d2828"

    # Text (blended from alpha)
    text = "#b5b0b0"
    subtext1 = "#efeaea"
    subtext0 = "#706a6a"

    # Overlays
    overlay0 = "#4b4646"
    overlay1 = "#645f5f"
    overlay2 = "#716c6b"

    # Syntax
    string = "#00ceb9"
    primitive = "#ffba92"
    property = "#ff9ae2"
    type = "#ecf58c"
    constant = "#93e9f6"
    comment = "#706a6a"

    # Semantic
    primary = "#fab283"
    success = "#12c905"
    warning = "#fcd53a"
    error = "#fc533a"
    info = "#edb2f1"
    interactive = "#89b5ff"

    # Catppuccin-compatible
    rosewater = "#f1ecec"
    flamingo = "#ffba92"
    pink = "#ff9ae2"
    mauve = "#9d7cd8"
    red = "#fc533a"
    maroon = "#ff917b"
    peach = "#fab283"
    yellow = "#fcd53a"
    green = "#12c905"
    teal = "#00ceb9"
    sky = "#93e9f6"
    sapphire = "#56b6c2"
    blue = "#89b5ff"
    lavender = "#edb2f1"

    # Cursor states
    cursorline = "#1c1717"
    secondary_cursor = "#706a6a"
    secondary_cursor_normal = "#706a6a"
    secondary_cursor_insert = "#267f20"
    secondary_cursor_select = "#878ec0"
  '';

  # Zed OpenCode OC-1 Dark theme JSON (raw string to avoid Nix attribute conflicts)
  zedOC1Theme = ''
    {
      "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
      "name": "OpenCode OC-1 Dark",
      "author": "OpenCode",
      "themes": [
        {
          "name": "OpenCode OC-1 Dark",
          "appearance": "dark",
          "style": {
            "background": "#131010",
            "editor.background": "#131010",
            "editor.foreground": "#b5b0b0",
            "editor.gutter.background": "#131010",
            "editor.line_number": "#4b4646",
            "editor.active_line_number": "#edb2f1",
            "editor.active_line.background": "#1c1717",
            "syntax": {
              "attribute": {"color": "#ecf58c", "font_style": null, "font_weight": null},
              "boolean": {"color": "#93e9f6", "font_style": null, "font_weight": null},
              "comment": {"color": "#706a6a", "font_style": "italic", "font_weight": null},
              "comment.doc": {"color": "#706a6a", "font_style": "italic", "font_weight": null},
              "constant": {"color": "#93e9f6", "font_style": null, "font_weight": null},
              "constructor": {"color": "#93e9f6", "font_style": null, "font_weight": null},
              "embedded": {"color": "#b5b0b0", "font_style": null, "font_weight": null},
              "emphasis": {"color": null, "font_style": "italic", "font_weight": null},
              "emphasis.strong": {"color": null, "font_style": null, "font_weight": 700},
              "enum": {"color": "#ecf58c", "font_style": null, "font_weight": null},
              "function": {"color": "#89b5ff", "font_style": null, "font_weight": null},
              "hint": {"color": "#706a6a", "font_style": "italic", "font_weight": null},
              "keyword": {"color": "#edb2f1", "font_style": null, "font_weight": null},
              "label": {"color": "#edb2f1", "font_style": null, "font_weight": null},
              "link_text": {"color": "#89b5ff", "font_style": null, "font_weight": null},
              "link_uri": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "number": {"color": "#ffba92", "font_style": null, "font_weight": null},
              "operator": {"color": "#93e9f6", "font_style": null, "font_weight": null},
              "predictive": {"color": "#706a6a", "font_style": "italic", "font_weight": null},
              "preproc": {"color": "#edb2f1", "font_style": null, "font_weight": null},
              "primary": {"color": "#89b5ff", "font_style": null, "font_weight": null},
              "property": {"color": "#ff9ae2", "font_style": null, "font_weight": null},
              "punctuation": {"color": "#716c6b", "font_style": null, "font_weight": null},
              "punctuation.bracket": {"color": "#716c6b", "font_style": null, "font_weight": null},
              "punctuation.delimiter": {"color": "#716c6b", "font_style": null, "font_weight": null},
              "punctuation.list_marker": {"color": "#edb2f1", "font_style": null, "font_weight": null},
              "punctuation.special": {"color": "#716c6b", "font_style": null, "font_weight": null},
              "string": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "string.escape": {"color": "#ffba92", "font_style": null, "font_weight": null},
              "string.regex": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "string.special": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "string.special.symbol": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "tag": {"color": "#89b5ff", "font_style": null, "font_weight": null},
              "text.literal": {"color": "#00ceb9", "font_style": null, "font_weight": null},
              "title": {"color": "#edb2f1", "font_style": null, "font_weight": 700},
              "type": {"color": "#ecf58c", "font_style": null, "font_weight": null},
              "variable": {"color": "#b5b0b0", "font_style": null, "font_weight": null},
              "variable.special": {"color": "#ffba92", "font_style": "italic", "font_weight": null},
              "variant": {"color": "#93e9f6", "font_style": null, "font_weight": null}
            },
            "text": "#b5b0b0",
            "text.muted": "#706a6a",
            "text.placeholder": "#4b4646",
            "text.accent": "#89b5ff",
            "status_bar.background": "#151313",
            "title_bar.background": "#151313",
            "toolbar.background": "#151313",
            "tab_bar.background": "#151313",
            "tab.active_background": "#131010",
            "tab.inactive_background": "#151313",
            "panel.background": "#131010",
            "border": "#252121",
            "border.focused": "#fab283",
            "border.selected": "#fab283",
            "border.transparent": "#25212100",
            "border.disabled": "#2d2828",
            "elevated_surface.background": "#191515",
            "surface.background": "#151313",
            "element.background": "#191515",
            "element.hover": "#252121",
            "element.active": "#2d2828",
            "element.selected": "#252121",
            "element.disabled": "#191515",
            "ghost_element.background": "#19151500",
            "ghost_element.hover": "#252121",
            "ghost_element.active": "#2d2828",
            "ghost_element.selected": "#252121",
            "ghost_element.disabled": "#191515",
            "drop_target.background": "#252121",
            "icon": "#b5b0b0",
            "icon.muted": "#706a6a",
            "icon.disabled": "#4b4646",
            "icon.placeholder": "#4b4646",
            "icon.accent": "#89b5ff",
            "scrollbar.thumb.background": "#25212180",
            "scrollbar.thumb.border": "#25212100",
            "scrollbar.thumb.hover_background": "#2d2828",
            "scrollbar.track.background": "#13101000",
            "scrollbar.track.border": "#25212100",
            "terminal.background": "#131010",
            "terminal.foreground": "#b5b0b0",
            "terminal.ansi.black": "#131010",
            "terminal.ansi.red": "#fc533a",
            "terminal.ansi.green": "#12c905",
            "terminal.ansi.yellow": "#fcd53a",
            "terminal.ansi.blue": "#89b5ff",
            "terminal.ansi.magenta": "#9d7cd8",
            "terminal.ansi.cyan": "#00ceb9",
            "terminal.ansi.white": "#b5b0b0",
            "terminal.ansi.bright_black": "#706a6a",
            "terminal.ansi.bright_red": "#ff917b",
            "terminal.ansi.bright_green": "#4ee541",
            "terminal.ansi.bright_yellow": "#fce06a",
            "terminal.ansi.bright_blue": "#a8c8ff",
            "terminal.ansi.bright_magenta": "#b99ce8",
            "terminal.ansi.bright_cyan": "#3ddbc8",
            "terminal.ansi.bright_white": "#efeaea",
            "link_text.hover": "#89b5ff",
            "error": "#fc533a",
            "error.background": "#fc533a20",
            "error.border": "#fc533a",
            "warning": "#fcd53a",
            "warning.background": "#fcd53a20",
            "warning.border": "#fcd53a",
            "success": "#12c905",
            "success.background": "#12c90520",
            "success.border": "#12c905",
            "info": "#89b5ff",
            "info.background": "#89b5ff20",
            "info.border": "#89b5ff",
            "hint": "#00ceb9",
            "hint.background": "#00ceb920",
            "hint.border": "#00ceb9",
            "predictive": "#706a6a",
            "renamed": "#89b5ff",
            "deleted": "#fc533a",
            "modified": "#fcd53a",
            "created": "#12c905",
            "hidden": "#706a6a",
            "conflict": "#ff9ae2",
            "ignored": "#4b4646",
            "players": [
              {"cursor": "#fab283", "background": "#fab28320", "selection": "#fab28330"}
            ]
          }
        }
      ]
    }
  '';

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
  installKubectlCompletion =
    pkgs.writeShellScriptBin "install-kubectl-completion" ''
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

  # Kill processes by port number - AI-friendly output
  kp = pkgs.buildGoModule {
    pname = "kp";
    version = "1.0.0";
    src = ./packages/kp;
    vendorHash = null;
  };

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
    pkgs.glab
    pkgs.bun
    pkgs.mongosh

    pkgs.go
    pkgs.air
    pkgs.templ

    pkgs.uv
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

    pkgs.uv

    dumptty
    kp
  ] ++ (lib.optionals isDarwin [
    pkgs.himalaya
  ]) ++ (lib.optionals isLinux [
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

  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
    GEMINI_CLI_SYSTEM_DEFAULTS_PATH =
      "${config.xdg.configHome}/gemini/settings.json";
    # .NET configuration
    DOTNET_ROOT = "${pkgs.dotnet-sdk}/share/dotnet";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
    # Go configuration - install binaries to ~/.local/bin (already in PATH)
    GOBIN = "$HOME/.local/bin";
  };

  home.file.".inputrc".source = ./configs/inputrc;
  # Silence "Last login:" on macOS and other login shells
  home.file.".hushlogin".text = "";

  xdg.configFile."ghostty/config".text = ghosttyConfig;
  xdg.configFile."ghostty/themes/OpenCode-OC1-Dark".text = ghosttyOC1Theme;
  xdg.configFile."helix/languages.toml".text = helix.languages;
  xdg.configFile."helix/config.toml".text = helix.config;
  xdg.configFile."helix/themes/opencode_oc1_dark.toml".text = helixOC1Theme;

  # Gemini CLI settings
  xdg.configFile."gemini/settings.json".source = ./configs/gemini-settings.json;

  # Zed editor settings
  xdg.configFile."zed/settings.json".source = ./configs/zed-settings.json;
  xdg.configFile."zed/keymap.json".source = ./configs/zed-keymap.json;
  xdg.configFile."zed/themes/opencode-oc1-dark.json".text = zedOC1Theme;

  # usql configuration
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
        fishTheme
        "set -g SHELL ${pkgs.fish}/bin/fish"
        "fish_add_path $HOME/.local/bin"
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

      fish_prompt = fishPrompt;
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
      user.email = "me@opustovit.com";
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
      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[ q'
      set -g allow-passthrough on
      set -s set-clipboard off

      # Copy bindings using smart yank
      bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "${yank}/bin/yank"

      bind -n C-k send-keys "clear" Enter

      # Load pain-control plugin
      run-shell ${tmuxSources."tmux-pain-control"}/pain_control.tmux
    '' + (if themeFamily == "opencode" then tmuxOC1Styles else ''
      # Catppuccin theme
      set -g @catppuccin_flavor "${tmuxCatppuccinFlavor}"
      set -g @catppuccin_window_status_style "rounded"
      run-shell ${tmuxSources."tmux-catppuccin"}/catppuccin.tmux
    '');
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

