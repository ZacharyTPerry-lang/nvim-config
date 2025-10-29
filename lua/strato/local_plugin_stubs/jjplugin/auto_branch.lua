-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/auto_branch.lua
local M = {}

local core = require('strato.local_plugin_stubs.jjplugin.core')
local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')

-- Create automatic child node when drift threshold exceeded
function M.create_auto_branch(filepath)
    local current_path = state.get_current_path(filepath)

    if #current_path == 0 then
        return false, "No current node to branch from"
    end

    -- Freeze the parent node
    local ok, err = state.freeze_node(filepath, current_path)
    if not ok then
        return false, "Failed to freeze parent: " .. tostring(err)
    end

    -- Get new commit ID for the child
    local new_commit = diff.get_current_commit()
    if not new_commit then
        return false, "Failed to get current commit"
    end

    -- Create child node with auto-generated description
    local description = string.format("auto-branch %s", os.date("%Y-%m-%d %H:%M"))
    local child_id, child_path = state.add_node(filepath, current_path, {
        description = description,
        commit_id = new_commit,
        is_main = true,
    })

    if not child_id then
        return false, "Failed to create child node"
    end

    -- Create actual jj commit for the child
    local result = core.execute({'new', '-m', description})
    if not result.success then
        return false, "Failed to create jj commit: " .. result.stderr
    end

    -- Get the new commit ID after jj new
    vim.cmd('checktime')  -- Reload buffer
    local child_commit = diff.get_current_commit()
    if child_commit then
        state.set_node_commit(filepath, child_path, child_commit)
    end

    -- Switch to child node
    state.set_current_node(filepath, child_path)

    -- Reset drift counter
    state.reset_drift(filepath)

    -- Update anchor to new commit
    if child_commit then
        state.set_anchor(filepath, child_commit)
    end

    vim.notify(string.format('Auto-branched: %s -> %s', current_path[#current_path], child_id), vim.log.levels.INFO)

    return true
end

-- Handle frozen node editing (immediate child creation)
function M.handle_frozen_edit(filepath)
    local current_path = state.get_current_path(filepath)

    if #current_path == 0 then
        return false, "No current node"
    end

    -- Check if current node is frozen
    if not state.is_frozen(filepath, current_path) then
        return false, "Node is not frozen"
    end

    -- Create child immediately
    local new_commit = diff.get_current_commit()

    local description = string.format("edit-frozen %s", os.date("%Y-%m-%d %H:%M"))
    local child_id, child_path = state.add_node(filepath, current_path, {
        description = description,
        commit_id = new_commit,
        is_main = true,
    })

    if not child_id then
        return false, "Failed to create child node"
    end

    -- Create jj commit
    local result = core.execute({'new', '-m', description})
    if not result.success then
        return false, "Failed to create jj commit: " .. result.stderr
    end

    -- Update with new commit
    vim.cmd('checktime')
    local child_commit = diff.get_current_commit()
    if child_commit then
        state.set_node_commit(filepath, child_path, child_commit)
    end

    -- Switch to child
    state.set_current_node(filepath, child_path)
    state.reset_drift(filepath)

    if child_commit then
        state.set_anchor(filepath, child_commit)
    end

    vim.notify(string.format('Frozen node edited: created child %s', child_id), vim.log.levels.INFO)

    return true
end

return M
