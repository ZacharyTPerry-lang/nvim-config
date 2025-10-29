-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/diff.lua
local M = {}

local core = require('strato.local_plugin_stubs.jjplugin.core')
local state = require('strato.local_plugin_stubs.jjplugin.state')

-- Parse jj diff --stat output
-- Format:
-- path/to/file.c | 45 +++++++++++++++++++++++---------
-- 1 file changed, 32 insertions(+), 13 deletions(-)
local function parse_diff_stat(output)
    local stats = {
        added = 0,
        deleted = 0,
        modified = 0,
    }

    -- Look for summary line: "N insertions(+), M deletions(-)"
    local insertions = output:match("(%d+) insertion")
    local deletions = output:match("(%d+) deletion")

    if insertions then
        stats.added = tonumber(insertions)
    end

    if deletions then
        stats.deleted = tonumber(deletions)
    end

    return stats
end

-- Calculate drift from anchor to current working copy
-- Returns drift-worthy line count (deletions + modifications)
-- Small additions (<10 lines) are ignored per design
function M.get_drift_from_anchor(filepath)
    local anchor = state.get_anchor(filepath)

    if not anchor then
        return 0
    end

    -- jj diff --from <anchor> --to @ --stat <filepath>
    local result = core.execute({
        'diff',
        '--from', anchor,
        '--to', '@',
        '--stat',
        filepath
    })

    if not result.success then
        vim.notify('Failed to calculate diff: ' .. result.stderr, vim.log.levels.WARN)
        return 0
    end

    local stats = parse_diff_stat(result.stdout)
    local config = state.get_config()

    -- Calculate drift: deletions + all modifications count
    -- Large additions (> threshold) also count
    local drift = stats.deleted

    if stats.added > config.small_addition_threshold then
        drift = drift + stats.added
    end

    return drift
end

-- Calculate diff between two specific commits
function M.get_diff_between(from_commit, to_commit, filepath)
    local result = core.execute({
        'diff',
        '--from', from_commit,
        '--to', to_commit,
        '--stat',
        filepath or ''
    })

    if not result.success then
        return nil, result.stderr
    end

    return parse_diff_stat(result.stdout)
end

-- Get current working copy commit ID
function M.get_current_commit()
    local template = 'commit_id'
    local result = core.execute({
        'log',
        '-r', '@',
        '--no-graph',
        '-T', template
    })

    if result.success and result.stdout then
        return vim.trim(result.stdout)
    end

    return nil
end

-- Get current change ID (stable across amendments)
function M.get_current_change_id()
    local template = 'change_id'
    local result = core.execute({
        'log',
        '-r', '@',
        '--no-graph',
        '-T', template
    })

    if result.success and result.stdout then
        return vim.trim(result.stdout)
    end

    return nil
end

return M
