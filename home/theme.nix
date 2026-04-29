# Single source of truth for theme colors across all applications.
# Every app-specific config (fish, ghostty, tmux, etc.) derives from this palette.
let
  themeMode = "light"; # "dark" or "light"
  themeFamily = "catppuccin"; # "opencode" or "catppuccin"

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

      # Text
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

      # Bright terminal variants
      bright_green = "4ee541";
      bright_yellow = "fce06a";
      bright_blue = "a8c8ff";
      bright_magenta = "b99ce8";
      bright_cyan = "3ddbc8";
    };
  };

  palette =
    if themeFamily == "opencode" then opencode_oc1.dark
    else (if themeMode == "dark" then catppuccin.macchiato else catppuccin.latte);

in {
  inherit themeMode themeFamily palette;

  ghosttyThemeName =
    if themeFamily == "opencode" then "OpenCode-OC1-Dark"
    else if themeMode == "dark" then "Catppuccin Macchiato"
    else "Catppuccin Latte";

  tmuxCatppuccinFlavor = if themeMode == "dark" then "macchiato" else "latte";
}
