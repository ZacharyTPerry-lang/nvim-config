-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/commands/drift.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')

function M.show_drift()
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

    local node = state.get_current_node(filepath)
    local drift = state.get_drift(filepath)
    local anchor = state.get_anchor(filepath)
    local config = state.get_config()

    -- Calculate real-time drift
    local realtime_drift = diff.get_drift_from_anchor(filepath)

    -- Build status message
    local lines = {}
    table.insert(lines, string.format("Drift Status for: %s", filepath))
    table.insert(lines, "")
    table.insert(lines, string.format("Current Node: %s (%s)",
        current_path[#current_path], node.description))
    table.insert(lines, string.format("Frozen: %s", node.frozen and "yes" or "no"))
    table.insert(lines, "")
    table.insert(lines, string.format("Stored Drift: %d lines", drift))
    table.insert(lines, string.format("Real-time Drift: %d lines", realtime_drift))
    table.insert(lines, string.format("Threshold: %d lines", config.auto_split_threshold))

    local total_drift = drift + realtime_drift
    table.insert(lines, string.format("Total: %d lines", total_drift))

    -- Progress bar
    local progress = math.min(total_drift / config.auto_split_threshold, 1.0)
    local bar_width = 40
    local filled = math.floor(progress * bar_width)
    local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
    table.insert(lines, string.format("[%s] %.1f%%", bar, progress * 100))

    if total_drift >= config.auto_split_threshold then
        table.insert(lines, "")
        table.insert(lines, "⚠ THRESHOLD EXCEEDED - Next :w will auto-branch")
    end

    table.insert(lines, "")
    table.insert(lines, string.format("Anchor: %s", anchor or "none"))

    -- Print to messages
    for _, line in ipairs(lines) do
        print(line)
    end
end

return M
