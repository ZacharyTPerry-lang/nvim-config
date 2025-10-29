-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/watcher.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')
local auto_branch = require('strato.local_plugin_stubs.jjplugin.auto_branch')

-- Track last save time per file to prevent rapid triggers
local last_save = {}

-- Main handler called on every file save
function M.on_file_save(filepath)
    -- Debounce: skip if saved less than 1 second ago
    local now = vim.loop.now()
    if last_save[filepath] and (now - last_save[filepath]) < 1000 then
        return
    end
    last_save[filepath] = now

    -- Only process files in the repo
    if not state.in_repo() then
        return
    end

    -- Skip if file has no tree yet (not initialized)
    if not state.file_has_tree(filepath) then
        return
    end

    local current_path = state.get_current_path(filepath)
    if #current_path == 0 then
        return
    end

    -- Check if current node is frozen - if so, auto-create child immediately
    if state.is_frozen(filepath, current_path) then
        auto_branch.handle_frozen_edit(filepath)
        return
    end

    -- Calculate drift from anchor
    local new_drift = diff.get_drift_from_anchor(filepath)

    -- Update drift in state
    local old_drift = state.get_drift(filepath)
    local total_drift = old_drift + new_drift

    state.update_drift(filepath, new_drift)

    -- Check if threshold exceeded
    local config = state.get_config()
    if total_drift >= config.auto_split_threshold then
        auto_branch.create_auto_branch(filepath)
    end
end

-- Setup autocmd for file watching
function M.setup()
    local group = vim.api.nvim_create_augroup('JJPluginWatcher', { clear = true })

    -- Watch for buffer writes
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        callback = function(args)
            local filepath = vim.api.nvim_buf_get_name(args.buf)

            -- Convert to relative path if in repo
            local repo = state.get_repo()
            if repo and filepath:sub(1, #repo) == repo then
                filepath = filepath:sub(#repo + 2)  -- +2 to skip the slash
            end

            -- Skip if not a regular file
            if filepath == "" or filepath:match("^%w+://") then
                return
            end

            M.on_file_save(filepath)
        end,
    })
end

return M
