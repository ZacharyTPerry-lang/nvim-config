return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    lazy = true,
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    keys = {
        { "<leader>pf", desc = "Find files" },
        { "<C-p>", desc = "Git files" },
        { "<leader>pws", desc = "Grep word" },
        { "<leader>pWs", desc = "Grep WORD" },
        { "<leader>ps", desc = "Grep string" },
        { "<leader>vh", desc = "Help tags" },
    },
    config = function()
        require('telescope').setup({})

        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        vim.keymap.set('n', '<leader>pws', function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>pWs', function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>ps', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") })
        end)
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
    end
}
