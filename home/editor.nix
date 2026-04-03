# Neovim and Helix editor configuration
{ config, lib, pkgs, ... }:

let
  helix = import ./helix.nix { inherit pkgs; };
in {
  programs.neovim = {
    enable = true;
    withPython3 = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [
      fzf-lua
      nvim-lspconfig
      gitsigns-nvim
      conform-nvim
      (nvim-treesitter.withPlugins (p: with p; [
        lua nix bash fish python typescript javascript tsx
        json toml yaml html css markdown markdown_inline
        rust go c cpp dockerfile git_config gitignore
        sql graphql proto terraform hcl
      ]))
      lualine-nvim
      nvim-autopairs
      bufferline-nvim
      lsp_lines-nvim
      indent-blankline-nvim
      mini-files

      { plugin = comment-nvim; optional = true; }
      blink-cmp
    ];
  };

  home.packages = helix.packages;

  xdg.configFile = {
    "helix/languages.toml".text = helix.languages;
    "helix/config.toml".text = helix.config;
    "helix/themes/opencode_oc1_dark.toml".source = ./configs/helix-oc1-theme.toml;
  };
}
