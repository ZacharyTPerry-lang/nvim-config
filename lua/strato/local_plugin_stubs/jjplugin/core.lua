local M = {}

function M.check_available()
    return vim.fn.executable('jj') == 1
end

function M.find_repo()
    local result = vim.fn.system('jj workspace root 2>/dev/null')

    if vim.v.shell_error == 0 then
        return vim.trim(result)
    end

  return nil
end

function M.execute(args, opts)
    opts = opts or {}
    local cmd = {'jj'}
    vim.list_extend(cmd, args)

    local state = require('strato.local_plugin_stubs.jjplugin.state')
    local cwd = opts.cwd or state.get_repo() or vim.fn.getcwd()

    local result = vim.system(cmd, {
        cwd = cwd,
        text = true
    }):wait()

    return {
        success = result.code  == 0,
        stdout = result.stdout or '',
        stderr = result.stderr or '',
        code = result.code,
    }
end

return M
