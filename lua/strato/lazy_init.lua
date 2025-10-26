local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Auto-create stub directories for local plugins
local local_specs_dir = vim.fn.stdpath("config") .. "/lua/strato/local_plugins"
local stubs_dir = vim.fn.stdpath("config") .. "/lua/strato/local_plugin_stubs"
vim.fn.mkdir(stubs_dir, "p")

local plugin_files = vim.fn.globpath(local_specs_dir, "*.lua", false, true)
for _, file_path in ipairs(plugin_files) do
  local plugin_name = vim.fn.fnamemodify(file_path, ":t:r")
  local stub_dir = stubs_dir .. "/" .. plugin_name
  vim.fn.mkdir(stub_dir, "p")

  local init = stub_dir .. "/init.lua"
  if vim.fn.filereadable(init) == 0 then
    local f = io.open(init, "w")
    if f then f:write("-- Auto-generated\n"); f:close() end
  end
end

require("lazy").setup({
  spec = {
    { import = "strato.lazy" },
    { import = "strato.local_plugins" },
  },
  change_detection = {
    enabled = false,
    notify = false
  },
})
