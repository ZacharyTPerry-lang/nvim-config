-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/commands/minor.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')
local core = require('strato.local_plugin_stubs.jjplugin.core')

function M.create_minor(description)
    local filepath = vim.fn.expand('%:.')
    if filepath == "" then
        vim.notify('No file in buffer', vim.log.levels.ERROR)
        return
    end

    if not state.file_has_tree(filepath) then
        vim.notify('No tree for this file. Use :JJMajor first', vim.log.levels.ERROR)
        return
    end

    local current_path = state.get_current_path(filepath)
    if #current_path == 0 then
        vim.notify('No current node. Use :JJMajor first', vim.log.levels.ERROR)
        return
    end

    -- Get parent path (one level up)
    local parent_path = {}
    if #current_path > 1 then
        parent_path = vim.list_slice(current_path, 1, #current_path - 1)
    else
        -- Already at major level, can't create sibling minors (would be majors)
        vim.notify('Use :JJMajor to create sibling at major level', vim.log.levels.ERROR)
        return
    end

    -- Get current commit (parent for new branch)
    local parent_commit = diff.get_current_commit()
    if not parent_commit then
        vim.notify('Failed to get current commit', vim.log.levels.ERROR)
        return
    end

    -- Create jj commit for new branch
    local result = core.execute({'new', parent_commit, '-m', description})
    if not result.success then
        vim.notify('jj new failed: ' .. result.stderr, vim.log.levels.ERROR)
        return
    end

    -- Get new commit ID
    vim.cmd('checktime')
    local new_commit = diff.get_current_commit()
    if not new_commit then
        vim.notify('Failed to get new commit ID', vim.log.levels.ERROR)
        return
    end

    -- Create sibling minor node
    local minor_id, minor_path = state.add_node(filepath, parent_path, {
        description = description,
        commit_id = new_commit,
        is_main = nil,  -- Let state decide based on siblings
    })

    if not minor_id then
        vim.notify('Failed to create minor node', vim.log.levels.ERROR)
        return
    end

    -- Switch to new minor
    state.set_current_node(filepath, minor_path)
    state.reset_drift(filepath)
    state.set_anchor(filepath, new_commit)

    vim.notify(string.format('Created minor %s: %s', minor_id, description), vim.log.levels.INFO)
end

return M
