-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/commands/freeze.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')

function M.freeze()
    local filepath = vim.fn.expand('%:.')
    if filepath == "" then
        vim.notify('No file in buffer', vim.log.levels.ERROR)
        return
    end

    if not state.file_has_tree(filepath) then
        vim.notify('No tree for this file', vim.log.levels.ERROR)
        return
    end

    local current_path = state.get_current_path(filepath)
    if #current_path == 0 then
        vim.notify('No current node', vim.log.levels.ERROR)
        return
    end

    local ok, err = state.freeze_node(filepath, current_path)
    if not ok then
        vim.notify('Failed to freeze: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end

    local node_id = current_path[#current_path]
    vim.notify(string.format('Frozen node %s (next edit will create child)', node_id), vim.log.levels.INFO)
end

function M.unfreeze()
    local filepath = vim.fn.expand('%:.')
    if filepath == "" then
        vim.notify('No file in buffer', vim.log.levels.ERROR)
        return
    end

    if not state.file_has_tree(filepath) then
        vim.notify('No tree for this file', vim.log.levels.ERROR)
        return
    end

    local current_path = state.get_current_path(filepath)
    if #current_path == 0 then
        vim.notify('No current node', vim.log.levels.ERROR)
        return
    end

    local ok, err = state.unfreeze_node(filepath, current_path)
    if not ok then
        vim.notify('Failed to unfreeze: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end

    local node_id = current_path[#current_path]
    vim.notify(string.format('Unfrozen node %s (can now edit directly)', node_id), vim.log.levels.INFO)
end

return M
