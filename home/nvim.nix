{ inputs }:
self: super:
{
  # Neovim plugins from pinned sources
  customVim = with self; {
    nvim-hotpot = vimUtils.buildVimPlugin {
      name = "nvim-hotpot";
      src = inputs.nvim-hotpot;
    };
    
    nvim-conform = vimUtils.buildVimPlugin {
      name = "nvim-conform";
      src = inputs.nvim-conform;
    };
    
    nvim-lspconfig = vimUtils.buildVimPlugin {
      name = "nvim-lspconfig";
      src = inputs.nvim-lspconfig;
    };
    
    nvim-comment = vimUtils.buildVimPlugin {
      name = "nvim-comment";
      src = inputs.nvim-comment;
    };
    
    nvim-gitsigns = vimUtils.buildVimPlugin {
      name = "nvim-gitsigns";
      src = inputs.nvim-gitsigns;
    };
    
    nvim-lualine = vimUtils.buildVimPlugin {
      name = "nvim-lualine";
      src = inputs.nvim-lualine;
    };

    nvim-lsplines = vimUtils.buildVimPlugin {
      name = "nvim-lsplines";
      src = inputs.nvim-lsplines;
    };
  };
}
