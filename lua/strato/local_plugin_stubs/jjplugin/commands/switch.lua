-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/commands/switch.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local core = require('strato.local_plugin_stubs.jjplugin.core')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')

-- Parse node path string like "A", "A1", "A1.1" into array
local function parse_path(path_str)
    local parts = {}
    for part in path_str:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    return parts
end

function M.switch_to_node(path_str)
    local filepath = vim.fn.expand('%:.')
    if filepath == "" then
        vim.notify('No file in buffer', vim.log.levels.ERROR)
        return
    end

    if not state.file_has_tree(filepath) then
        vim.notify('No tree for this file', vim.log.levels.ERROR)
        return
    end

    local path = parse_path(path_str)
    if #path == 0 then
        vim.notify('Invalid path', vim.log.levels.ERROR)
        return
    end

    -- Verify path exists
    local ok, err = state.set_current_node(filepath, path)
    if not ok then
        vim.notify('Path not found: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end

    -- Get the node's commit
    local node = state.get_current_node(filepath)
    if not node or not node.main_commit then
        vim.notify('Node has no commit', vim.log.levels.ERROR)
        return
    end

    -- Switch jj working copy to that commit
    local result = core.execute({'edit', node.main_commit})
    if not result.success then
        vim.notify('jj edit failed: ' .. result.stderr, vim.log.levels.ERROR)
        return
    end

    -- Reload buffer
    vim.cmd('checktime')
    vim.cmd('edit!')  -- Force reload without confirmation

    -- Update anchor
    state.set_anchor(filepath, node.main_commit)

    vim.notify(string.format('Switched to %s: %s', path_str, node.description), vim.log.levels.INFO)
end

return M
