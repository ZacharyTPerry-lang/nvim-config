return {
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        event = "VeryLazy",  -- Load after startup, in background
        build = "make install_jsregexp",
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
            local ls = require("luasnip")
            ls.filetype_extend("javascript", { "jsdoc" })

            -- Expand snippet at cursor
            vim.keymap.set({"i"}, "<C-s>e", function() ls.expand() end, {silent = true})

            -- Jump forward/backward in snippet
            vim.keymap.set({"i", "s"}, "<C-s>;", function() ls.jump(1) end, {silent = true})
            vim.keymap.set({"i", "s"}, "<C-s>,", function() ls.jump(-1) end, {silent = true})

            -- Cycle through snippet choices
            vim.keymap.set({"i", "s"}, "<C-E>", function()
                if ls.choice_active() then
                    ls.change_choice(1)
                end
            end, {silent = true})
        end,
    }
}
