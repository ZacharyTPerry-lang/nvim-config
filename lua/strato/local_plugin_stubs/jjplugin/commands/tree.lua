-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/commands/tree.lua
local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')

-- Recursively build tree lines
local function build_tree_lines(node, path, current_path, depth, is_last_sibling, prefix)
    local lines = {}

    -- Build the connector
    local connector = ""
    if depth > 0 then
        connector = prefix .. (is_last_sibling and "└── " or "├── ")
    end

    -- Build node info
    local markers = {}
    if node.is_main then
        table.insert(markers, "MAIN")
    end
    if node.frozen then
        table.insert(markers, "FROZEN")
    end
    if node.closed then
        table.insert(markers, "CLOSED")
    end

    local marker_str = ""
    if #markers > 0 then
        marker_str = "[" .. table.concat(markers, ",") .. "] "
    end

    -- Check if this is current node
    local is_current = vim.deep_equal(path, current_path)
    local current_marker = is_current and "→ " or ""

    -- Build drift info
    local drift_str = ""
    if node.drift and node.drift > 0 then
        drift_str = string.format(" (drift: %d)", node.drift)
    end

    local line = string.format("%s%s%s%s: %s%s",
        connector,
        current_marker,
        marker_str,
        node.id,
        node.description,
        drift_str
    )

    table.insert(lines, line)

    -- Process children
    if node.minors then
        local minor_ids = vim.tbl_keys(node.minors)
        table.sort(minor_ids)

        for i, minor_id in ipairs(minor_ids) do
            local minor = node.minors[minor_id]
            local minor_path = vim.deepcopy(path)
            table.insert(minor_path, minor_id)

            local is_last = (i == #minor_ids)
            local child_prefix = prefix
            if depth > 0 then
                child_prefix = prefix .. (is_last_sibling and "    " or "│   ")
            end

            local child_lines = build_tree_lines(minor, minor_path, current_path, depth + 1, is_last, child_prefix)
            for _, child_line in ipairs(child_lines) do
                table.insert(lines, child_line)
            end
        end
    end

    return lines
end

function M.show_tree()
    local filepath = vim.fn.expand('%:.')
    if filepath == "" then
        vim.notify('No file in buffer', vim.log.levels.ERROR)
        return
    end

    if not state.file_has_tree(filepath) then
        vim.notify('No tree for this file. Use :JJMajor to initialize', vim.log.levels.ERROR)
        return
    end

    local file_state = state.get_file_state(filepath)
    local current_path = file_state.current_path

    local lines = {}
    table.insert(lines, "Tree for: " .. filepath)
    table.insert(lines, "")

    -- Get majors in order
    local major_ids = vim.tbl_keys(file_state.majors)
    table.sort(major_ids)

    for _, major_id in ipairs(major_ids) do
        local major = file_state.majors[major_id]
        local major_lines = build_tree_lines(major, {major_id}, current_path, 0, false, "")
        for _, line in ipairs(major_lines) do
            table.insert(lines, line)
        end
        table.insert(lines, "")
    end

    -- Create or reuse buffer
    local bufname = 'JJ Tree: ' .. filepath
    local existing_buf = vim.fn.bufnr(bufname)

    local buf
    if existing_buf ~= -1 then
        -- Reuse existing buffer
        buf = existing_buf
        -- Make modifiable temporarily to update content
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    else
        -- Create new buffer
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_name(buf, bufname)
    end

    -- Open in split (or switch to existing window)
    local tree_win = vim.fn.bufwinid(buf)
    if tree_win ~= -1 then
        -- Buffer already visible, just switch to it
        vim.api.nvim_set_current_win(tree_win)
    else
        -- Open new split
        vim.cmd('split')
        vim.api.nvim_win_set_buf(0, buf)
    end

    -- Add syntax highlighting
    vim.api.nvim_buf_call(buf, function()
        vim.cmd('syntax match JJTreeMain /\\[MAIN\\]/')
        vim.cmd('syntax match JJTreeFrozen /\\[FROZEN\\]/')
        vim.cmd('syntax match JJTreeCurrent /→/')
        vim.cmd('syntax match JJTreeDrift /(drift: \\d\\+)/')

        vim.cmd('highlight JJTreeMain guifg=#a6e3a1 ctermfg=green')
        vim.cmd('highlight JJTreeFrozen guifg=#f38ba8 ctermfg=red')
        vim.cmd('highlight JJTreeCurrent guifg=#f9e2af ctermfg=yellow gui=bold cterm=bold')
        vim.cmd('highlight JJTreeDrift guifg=#89b4fa ctermfg=blue')
    end)
end

return M
