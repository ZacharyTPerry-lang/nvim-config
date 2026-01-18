-- This one is the real deal not a shim.
-- JJ integration plugin by Zachary Perry

local M = {}

local state = require('strato.local_plugin_stubs.jjplugin.state')
local parser = require('strato.local_plugin_stubs.jjplugin.parser')
local core = require('strato.local_plugin_stubs.jjplugin.core')
local watcher = require('strato.local_plugin_stubs.jjplugin.watcher')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')

-- Command modules
local cmd_minor = require('strato.local_plugin_stubs.jjplugin.commands.minor')
local cmd_freeze = require('strato.local_plugin_stubs.jjplugin.commands.freeze')
local cmd_switch = require('strato.local_plugin_stubs.jjplugin.commands.switch')
local cmd_tree = require('strato.local_plugin_stubs.jjplugin.commands.tree')
local cmd_drift = require('strato.local_plugin_stubs.jjplugin.commands.drift')

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

    vim.api.nvim_create_user_command('JJMajor', function(opts)
        local description = opts.args
        if description == "" then
            vim.notify('Usage: :JJMajor <description>', vim.log.levels.ERROR)
            return
        end

        local filepath = vim.fn.expand('%:.')
        if filepath == "" then
            vim.notify('No file in buffer', vim.log.levels.ERROR)
            return
        end

        -- Get current commit
        local commit_id = diff.get_current_commit()
        if not commit_id then
            vim.notify('Failed to get current commit', vim.log.levels.ERROR)
            return
        end

        -- Create major node
        local major_id, major_path = state.add_node(filepath, {}, {
            description = description,
            commit_id = commit_id,
            is_main = nil,  -- Let state decide (first major will be main)
        })

        if not major_id then
            vim.notify('Failed to create major node', vim.log.levels.ERROR)
            return
        end

        -- Set as current
        state.set_current_node(filepath, major_path)
        state.set_anchor(filepath, commit_id)
        state.reset_drift(filepath)

        vim.notify(string.format('Created major %s: %s', major_id, description), vim.log.levels.INFO)
    end, {nargs = '+', desc = 'Create new major version'})

    vim.api.nvim_create_user_command('JJMinor', function(opts)
        local description = opts.args
        if description == "" then
            vim.notify('Usage: :JJMinor <description>', vim.log.levels.ERROR)
            return
        end
        cmd_minor.create_minor(description)
    end, {nargs = '+', desc = 'Create sibling minor version'})

    vim.api.nvim_create_user_command('JJFreeze', function()
        cmd_freeze.freeze()
    end, {desc = 'Freeze current node (make immutable)'})

    vim.api.nvim_create_user_command('JJUnfreeze', function()
        cmd_freeze.unfreeze()
    end, {desc = 'Unfreeze current node (allow editing)'})

    -- Helper function for path completion
    local function get_valid_paths()
        local filepath = vim.fn.expand('%:.')
        if filepath == "" or not state.file_has_tree(filepath) then
            return {}
        end

        local paths = {}
        local nodes = state.walk_tree(filepath)

        for _, node in ipairs(nodes) do
            -- Format path as "A", "A.1", "A.1.1" etc
            local path_str = table.concat(node.path, ".")
            table.insert(paths, path_str)
        end

        return paths
    end

    vim.api.nvim_create_user_command('JJSwitch', function(opts)
        local path = opts.args
        if path == "" then
            vim.notify('Usage: :JJSwitch <path> (e.g., A or A.1)', vim.log.levels.ERROR)
            return
        end
        cmd_switch.switch_to_node(path)
    end, {
        nargs = 1,
        desc = 'Switch to different node in tree',
        complete = function(arg_lead, cmd_line, cursor_pos)
            local paths = get_valid_paths()

            -- Filter by what user has typed
            if arg_lead ~= "" then
                return vim.tbl_filter(function(path)
                    return vim.startswith(path, arg_lead)
                end, paths)
            end

            return paths
        end
    })

    vim.api.nvim_create_user_command('JJTree', function()
        cmd_tree.show_tree()
    end, {desc = 'Show tree visualization'})

    vim.api.nvim_create_user_command('JJDrift', function()
        cmd_drift.show_drift()
    end, {desc = 'Show drift status'})
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
    watcher.setup()
end

function M.get_state()
    return state.get_all()
end

return M
