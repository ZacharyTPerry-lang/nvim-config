local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {

    -- UI + core plugins (no LSP, no Treesitter yet)
    { "nvim-lualine/lualine.nvim" },
    { "nvim-tree/nvim-web-devicons" },
    { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
    { "nvim-tree/nvim-tree.lua" },

    -- Completion engine
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "hrsh7th/cmp-cmdline" },
    { "hrsh7th/cmp-nvim-lsp" },

    -- Snippet support
    { "L3MON4D3/LuaSnip" },
    { "saadparwaiz1/cmp_luasnip" },

    -- Formatting and notifications
    { "stevearc/conform.nvim" },
    { "j-hui/fidget.nvim" },

    -- Mason (LSP manager)
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },

    -- Color scheme
    { "rebelot/kanagawa.nvim" },

    -- tree man
    -- Tree-sitter core + context
    {
	    "nvim-treesitter/nvim-treesitter",
	    build = ":TSUpdate",
	    config = function()
		    require("nvim-treesitter.configs").setup({
			    ensure_installed = {
				    "c", "lua", "vim", "vimdoc", "javascript", "typescript", "go", "bash", "rust"
			    },
			    highlight = {
				    enable = true,
				    additional_vim_regex_highlighting = false,
			    },
			    indent = { enable = true },
		    })
	    end
    },

    {
	    "nvim-treesitter/nvim-treesitter-context",
	    config = function()
		    require("treesitter-context").setup({
			    enable = true,
			    multiline_threshold = 20,
			    line_numbers = true,
		    })
	    end
    }
    

  },

  change_detection = { notify = false },
})

-- Apply colorscheme only after Lazy has loaded plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.cmd.colorscheme("kanagawa")
  end,
})

