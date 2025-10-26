-- Define at module level (file scope)
local function ColorMyPencils(color)
	color = color or "kanagawa"
	vim.cmd.colorscheme(color)

	--vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	--vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end

return {
    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
        config = function()
            ColorMyPencils()
            -- Set up filetype-based colorscheme switching
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "*",
                callback = function()
                    local ft = vim.bo.filetype
                    if ft == "zig" then
                        -- Load tokyonight if not loaded
                        if not pcall(vim.cmd.colorscheme, "tokyonight-night") then
                            vim.cmd.colorscheme("kanagawa")
                        end
                    elseif ft == "go" then
                        if not pcall(vim.cmd.colorscheme, "gruvbox") then
                            vim.cmd.colorscheme("kanagawa")
                        end
                    elseif ft == "rust" then
                        if not pcall(vim.cmd.colorscheme, "brightburn") then
                            vim.cmd.colorscheme("kanagawa")
                        end
                    else
                        -- Default back to kanagawa for everything else
                        if vim.g.colors_name ~= "kanagawa" then
                            vim.cmd.colorscheme("kanagawa")
                        end
                    end
                end,
            })
        end
    },

    {
        "ellisonleao/gruvbox.nvim",
        name = "gruvbox",
        lazy = true,
        ft = "go",
        config = function()
            require("gruvbox").setup({
                terminal_colors = true,
                undercurl = true,
                underline = false,
                bold = true,
                italic = {
                    strings = false,
                    emphasis = false,
                    comments = false,
                    operators = false,
                    folds = false,
                },
                strikethrough = true,
                invert_selection = false,
                invert_signs = false,
                invert_tabline = false,
                invert_intend_guides = false,
                inverse = true,
                contrast = "",
                palette_overrides = {},
                overrides = {},
                dim_inactive = false,
                transparent_mode = false,
            })
        end,
    },

    {
        "folke/tokyonight.nvim",
        lazy = true,
        ft = "zig",
        config = function()
            require("tokyonight").setup({
                style = "storm",
                transparent = true,
                terminal_colors = true,
                styles = {
                    comments = { italic = false },
                    keywords = { italic = false },
                    sidebars = "dark",
                    floats = "dark",
                },
            })
        end
    },

    {
        "erikbackman/brightburn.vim",
        lazy = true,
        ft = "rust",
    },
}
