return {
    "tjdevries/php.nvim",
    ft = "php",
    dependencies = {
        "nvim-treesitter/nvim-treesitter"
    },
    config = function()
        require("php").setup({})
    end
}
