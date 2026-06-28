# Neovim and Helix editor configuration
{ full ? false }:
{ config, lib, pkgs, ... }:

if full then {
  programs.neovim = {
    enable = true;
    withPython3 = true;
    withRuby = true;
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

} else {
  home.packages = [ pkgs.neovim ];
}
