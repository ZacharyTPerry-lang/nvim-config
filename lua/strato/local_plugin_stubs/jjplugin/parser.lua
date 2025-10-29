-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/parser.lua

local M = {}

local function split(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end

local function parse_log_line(line)
    if not line or line == "" then
        return nil
    end

    local parts = split(line, "|")
    if #parts < 3 then
        return nil
    end

    return {
        commit_id = parts[1],
        change_id = parts[2],
        description = parts[3],
    }
end

function M.parse_log(output)
    local commits = {}
    for line in string.gmatch(output, "[^\n]+") do
        local commit = parse_log_line(line)
        if commit then
            table.insert(commits, commit)
        end
    end
    return commits
end

function M.parse_status(output)
    local lines = {}
    for line in string.gmatch(output, "[^\n]+") do
        table.insert(lines, line)
    end

    return {
        raw = output,
        lines = lines,
    }
end

return M
