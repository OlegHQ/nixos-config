# Ghostty terminal configuration
{ config, lib, pkgs, ... }:

let
  theme = import ./theme.nix;
  p = theme.palette;

  ghosttyConfig = ''
    theme = "${theme.ghosttyThemeName}"
    font-family = "PragmataPro Liga"
    cursor-style = block
    shell-integration-features = no-cursor
    keybind = "ctrl+l=unbind"

    clipboard-read = "allow"
    clipboard-write = "allow"
    clipboard-paste-protection = false
    clipboard-paste-bracketed-safe = false
  '';

  # Generated from palette — single source of truth
  ghosttyOC1Theme = ''
    background = ${p.base}
    foreground = ${p.text}
    cursor-color = ${p.primary}
    selection-background = ${p.surface1}
    selection-foreground = ${p.subtext1}

    # Normal colors (0-7)
    palette = 0=#${p.base}
    palette = 1=#${p.red}
    palette = 2=#${p.green}
    palette = 3=#${p.yellow}
    palette = 4=#${p.blue}
    palette = 5=#${p.mauve}
    palette = 6=#${p.teal}
    palette = 7=#${p.text}

    # Bright colors (8-15)
    palette = 8=#${p.subtext0}
    palette = 9=#${p.maroon}
    palette = 10=#${p.bright_green}
    palette = 11=#${p.bright_yellow}
    palette = 12=#${p.bright_blue}
    palette = 13=#${p.bright_magenta}
    palette = 14=#${p.bright_cyan}
    palette = 15=#${p.subtext1}
  '';

in {
  xdg.configFile = {
    "ghostty/config".text = ghosttyConfig;
  } // lib.optionalAttrs (theme.themeFamily == "opencode") {
    "ghostty/themes/OpenCode-OC1-Dark".text = ghosttyOC1Theme;
  };
}
