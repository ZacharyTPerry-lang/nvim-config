-- This one is the real deal not a shim.
-- JJ integration plugin by Zachary Perry

local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local parser = require('strato.local_plugin_stubs.jjplugin.parser')
local core = require('strato.local_plugin_stubs.jjplugin.core')

--
-- User commands section
--

local function create_commands()
    vim.api.nvim_create_user_command("JJStatus", function()
        local result =  core.execute({'status'})
        if result.success then
            print(result.stdout)
        else
            vim.notify('jj status failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, { desc = "Shows the status of the working copy, including unreacked files and changes" })

    vim.api.nvim_create_user_command("JJLog", function()
        local template = 'commit_id ++ "|" ++ change_id ++ "|" ++ description.first_line() ++ "\\n"'
        local result = core.execute({'log', '--no-graph', '-T', template})

        if result.success then
            local commits = parser.parse_log(result.stdout)

            for _, commit in ipairs(commits) do
                print(string.format("%s | %s | %s",
                    commit.commit_id:sub(1, 8),
                    commit.change_id:sub(1, 8),
                    commit.description
                ))
            end
        else
            vim.notify('jj log failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, { desc = "Display revision history with graph visualizations" })

    vim.api.nvim_create_user_command("JJCommit", function(opts)
        local description = opts.args
        if description == "" then
            description = string.format("Checkpoint %s", os.date("%Y-%m-%d %H:%M"))
        end

        local result = core.execute({'new', '-m', description})
        if result.success then
            vim.notify('Checkpoint created', vim.log.levels.INFO)
        else
            vim.notify('jj new failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, {nargs = '?', desc = 'Create checkpoint (auto-timestamped or custom)' })

    vim.api.nvim_create_user_command('JJEdit', function(opts)
        local change_id = opts.args
        if change_id == "" then
            vim.notify('Usage: :JJEdit <change_id>', vim.log.levels.ERROR)
            return
        end

        local result = core.execute({'edit', change_id})
        if result.success then
            vim.notify('Switched to ' .. change_id, vim.log.levels.INFO)
        else
            vim.notify('jj edit failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, {nargs = 1, desc = 'Switch working copy to specific change' })

    vim.api.nvim_create_user_command('JJNew', function(opts)
        local args = vim.split(opts.args, " ", {trimempty = true})
        if #args == 0 then
            vim.notify('Usage: :JJNew <parent_id> [description]', vim.log.levels.ERROR)
            return
        end

        local parent_id = args[1]
        local description = table.concat(vim.list_slice(args, 2), " ")
        if description == "" then
            description = string.format("Branch from %s", parent_id:sub(1,8))
        end

        local result = core.execute({'new', parent_id, '-m', description})
        if result.success then
            vim.notify('Created new change from ' .. parent_id, vim.log.levels.INFO)
        else
            vim.notify('jj new failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, {nargs = '+', desc = 'Create new change from specific parent'})

    vim.api.nvim_create_user_command('JJDescribe', function(opts)
        local description = opts.args
        if description == "" then
            vim.notify('Usage: :JJDescribe <description>', vim.log.levels.ERROR)
            return
        end

        local result = core.execute({'describe', '-m', description})
        if result.success then
            vim.notify('Description updated' , vim.log.levels.INFO)
        else
            vim.notify('jj describe failed: ' .. result.stderr, vim.log.levels.ERROR)
        end
    end, {nargs = '+', desc = 'Update current working copy description'})
end

local function setup_autocmds()
    local group = vim.api.nvim_create_augroup('JJPlugin', { clear = true })

    vim.api.nvim_create_autocmd({ 'DirChanged', 'BufEnter' }, {
        group = group,
        callback = function()
            local repo_root = core.find_repo()
            state.set_repo(repo_root)
        end,
        })
    end

function M.setup(opts)
    opts = opts or {}

    if not core.check_available() then
        vim.notify('jj binary not found', vim.log.levels.WARN)
        state.set_available(false)
        return
    end

    state.set_available(true)
    local repo_root = core.find_repo()
    state.set_repo(repo_root)
    setup_autocmds()
    create_commands()
end

function M.get_state()
    return state.get_all()
end

return M
