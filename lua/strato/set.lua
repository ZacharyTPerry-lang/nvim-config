vim.opt.guicursor = ""
vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = ""
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10

vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
        vim.opt_local.signcolumn = "yes:1"
    end,
})

vim.api.nvim_create_autocmd({"BufEnter", "FileType"}, {
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "r", "o" })
    end,
})

vim.opt.statusline = "%f %h%m%r%=VULKAN:%{luaeval('get_vulkan_mode()')} %l,%c %P"

_G.get_current_line = function()
    return string.format("%4d", vim.fn.line('.'))
end
