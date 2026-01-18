-- lua/strato/local_plugins/jjplugin.lua
return {
    name = "jjplugin",
    dir = vim.fn.expand("~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin"),
    event = "VeryLazy",
    config = function()
       require("strato.local_plugin_stubs.jjplugin").setup()
    end,
}
