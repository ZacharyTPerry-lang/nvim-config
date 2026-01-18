-- We set leader to spacebar right here at the top best command. We also make file explorer here.
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>f", vim.cmd.Ex)

--
-- Smart tab indentation functions
--

local function smart_indent()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local before_cursor = line:sub(1, col-1)
  local leading_space = before_cursor:match('^%s*')
  local offset = col - #leading_space

  -- Add indentation to the line
  local current_line_num = vim.fn.line('.')
  vim.fn.setline(current_line_num, string.rep(' ', vim.bo.shiftwidth) .. line)

  -- Position cursor: maintain it since it was pissing me of to indent and the cursor did not move
  local new_col = vim.bo.shiftwidth + col
  vim.fn.cursor(current_line_num, new_col)
end

local function smart_dedent()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local before_cursor = line:sub(1, col-1)
  local leading_space = before_cursor:match('^%s*')
  local offset = col - #leading_space

  -- Remove indentation
  local dedent_amount = math.min(vim.bo.shiftwidth, #leading_space)
  local new_line = line:sub(dedent_amount + 1)
  local current_line_num = vim.fn.line('.')
  vim.fn.setline(current_line_num, new_line)

  -- Position cursor
  local new_col = math.max(1, col - dedent_amount)
  vim.fn.cursor(current_line_num, new_col)
end

--
-- We make an autocomment bind because I am insane
--

vim.keymap.set('i', '<C-CR>', function()
    local line = vim.api.nvim_get_current_line()

    -- Check if line starts with comment markers (with optional leading whitespace)
    local leading_ws = line:match('^(%s*)')  -- Capture leading whitespace
    local trimmed = line:match('^%s*(.*)$')

    if trimmed:match('^%-%- ') then          -- Lua: starts with --
        return '<CR>' .. leading_ws .. '-- '
    elseif trimmed:match('^// ') then        -- C++: starts with //
        return '<CR>' .. leading_ws .. '// '
    elseif trimmed:match('^# ') then         -- Python: starts with #
        return '<CR>' .. leading_ws .. '# '
    elseif trimmed:match('^/%* ') then       -- C block: starts with /*
        return '<CR>' .. leading_ws .. '/* '
    else
        return '<CR>'
    end
end, {expr = true, desc = "Continue comment on new line"})

--
-- Harpoon binds section
--

-- Harpoon config (Miryoku-compatible, all base layer)
vim.keymap.set("n", "<leader>a", function() require("harpoon"):list():add() end, {desc = "Harpoon add"})
vim.keymap.set("n", "<C-e>", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end)  -- Keep for now, evaluate
vim.keymap.set("n", "<leader>j", function() require("harpoon"):list():select(1) end, {desc = "Harpoon file 1"})
vim.keymap.set("n", "<leader>k", function() require("harpoon"):list():select(2) end, {desc = "Harpoon file 2"})
vim.keymap.set("n", "<leader>l", function() require("harpoon"):list():select(3) end, {desc = "Harpoon file 3"})
vim.keymap.set("n", "<leader>'", function() require("harpoon"):list():select(4) end, {desc = "Harpoon file 4"})
vim.keymap.set("n", "<leader>hp", function() require("harpoon"):list():prev() end, {desc = "Harpoon prev"})
vim.keymap.set("n", "<leader>hn", function() require("harpoon"):list():next() end, {desc = "Harpoon next"})--

-- Telescope Enhanced Navigation
--

-- Telescope (lazy-loaded in functions)
vim.keymap.set('n', '<leader>pf', function() require('telescope.builtin').find_files() end)
vim.keymap.set('n', '<C-p>', function() require('telescope.builtin').git_files() end)

-- Search/Grep
vim.keymap.set('n', '<leader>ps', function()
    require('telescope.builtin').grep_string({ search = vim.fn.input("Grep > ") })
end)
vim.keymap.set('n', '<leader>pws', function()
    local word = vim.fn.expand("<cword>")
    require('telescope.builtin').grep_string({ search = word })
end)
vim.keymap.set('n', '<leader>pWs', function()
    local word = vim.fn.expand("<cWORD>")
    require('telescope.builtin').grep_string({ search = word })
end)
vim.keymap.set('n', '<leader>lg', function() require('telescope.builtin').live_grep() end)

-- LSP/Symbols
vim.keymap.set('n', '<leader>ds', function() require('telescope.builtin').lsp_document_symbols() end)
vim.keymap.set('n', '<leader>ws', function() require('telescope.builtin').lsp_dynamic_workspace_symbols() end)

-- Help and buffers
vim.keymap.set('n', '<leader>vh', function() require('telescope.builtin').help_tags() end)
vim.keymap.set('n', '<leader>fb', function() require('telescope.builtin').buffers() end)

-- Recent Files & History
vim.keymap.set('n', '<leader>fr', function() require('telescope.builtin').oldfiles() end)
vim.keymap.set('n', '<leader>fh', function() require('telescope.builtin').command_history() end)
vim.keymap.set('n', '<leader>fs', function() require('telescope.builtin').search_history() end)

-- Vim Internals
vim.keymap.set('n', '<leader>fm', function() require('telescope.builtin').marks() end)
vim.keymap.set('n', '<leader>fk', function() require('telescope.builtin').keymaps() end)
vim.keymap.set('n', '<leader>fo', function() require('telescope.builtin').vim_options() end)
vim.keymap.set('n', '<leader>fR', function() require('telescope.builtin').registers() end)

--
-- Normal bind work tab binding
--

-- Normal mode
vim.keymap.set("n", "<Tab>", ">>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-Tab>", "<<", { noremap = true, silent = true })

-- Visual mode (with reselect)
vim.keymap.set("v", "<Tab>", ">gv", { noremap = true, silent = true })
vim.keymap.set("v", "<S-Tab>", "<gv", { noremap = true, silent = true })

-- Insert mode (smart cursor positioning)
vim.keymap.set("i", "<Tab>", function() smart_indent() end, { noremap = true, silent = true })
vim.keymap.set("i", "<S-Tab>", function() smart_dedent() end, { noremap = true, silent = true })

-- Normal mode newline and prev line
vim.keymap.set("n", "<S-CR>", "o<Esc>", { desc = "Insert blank line below" })
vim.keymap.set("n", "<Tab><CR>", "O<Esc>", { desc = "Insert blank line above" })

--
-- General bind work
--

-- Window Navigation
vim.keymap.set("n", "<M-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<M-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<M-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<M-l>", "<C-w>l", { desc = "Window right" })

-- Window Resize
vim.keymap.set("n", "<M-Left>", "<C-w><", { desc = "Decrease width" })
vim.keymap.set("n", "<M-Right>", "<C-w>>", { desc = "Increase width" })
vim.keymap.set("n", "<M-Up>", "<C-w>+", { desc = "Increase height" })
vim.keymap.set("n", "<M-Down>", "<C-w>-", { desc = "Decrease height" })

-- Buffer Navigation
vim.keymap.set("n", "<M-n>", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<M-p>", ":bprevious<CR>", { desc = "Previous buffer" })

-- Buffer Management
vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bD", ":bdelete!<CR>", { desc = "Force delete buffer" })

-- Quickfix Navigation
vim.keymap.set("n", "[q", ":cprevious<CR>", { desc = "Previous quickfix" })
vim.keymap.set("n", "]q", ":cnext<CR>", { desc = "Next quickfix" })
vim.keymap.set("n", "[Q", ":cfirst<CR>", { desc = "First quickfix" })
vim.keymap.set("n", "]Q", ":clast<CR>", { desc = "Last quickfix" })

-- Quickfix Management
vim.keymap.set("n", "<leader>qo", ":copen<CR>", { desc = "Open quickfix" })
vim.keymap.set("n", "<leader>qc", ":cclose<CR>", { desc = "Close quickfix" })

-- Location List (file-local quickfix)
vim.keymap.set("n", "[l", ":lprevious<CR>", { desc = "Previous location" })
vim.keymap.set("n", "]l", ":lnext<CR>", { desc = "Next location" })
vim.keymap.set("n", "[L", ":lfirst<CR>", { desc = "First location" })
vim.keymap.set("n", "]L", ":llast<CR>", { desc = "Last location" })

-- Assembly viewer keybinds
vim.keymap.set("n", "<leader>at", function() vim.cmd("AsmViewToggle") end, { desc = "Toggle Assembly View" })
vim.keymap.set("n", "<leader>al", function() vim.cmd("AsmViewMode") end, { desc = "Toggle PTX/SASS View" })

-- Unmap a few things they were issues
vim.keymap.set('n', 'a', '<nop>', { desc = 'Disabled (use I for insert)' })
vim.keymap.set('n', 'v', '<nop>', {desc = "Visual mode disabled"})
vim.keymap.set('n', 'V', '<nop>', {desc = "Visual line mode disabled"})
vim.keymap.set({'n', 'v', 'i'}, '<C-c>', '<Nop>', {silent = true, desc = "Disabled (use jj or Esc)"})
--vim.keymap.set({'n', 'v', 'i'}, '<C-m>', '<Nop>', {silent = true, desc = "Disabled (use Enter)"})

-- Left-to-right ordering on home row
vim.keymap.set('n', 'j', 'h', {desc = "Move left"})   -- j = left
vim.keymap.set('n', 'k', 'j', {desc = "Move down"})   -- k = down
vim.keymap.set('n', 'l', 'k', {desc = "Move up"})     -- l = up
vim.keymap.set('n', ';', 'l', {desc = "Move right"})  -- ; = right
vim.keymap.set('n', "'", 'l', {desc = "Move right (apostrophe)"})  -- ' also = right

--
-- Del remaps kinda important
--

vim.keymap.set('i', '<C-e>', '<Del>', {desc = "Delete forward"})

--
-- Kill like 3/5ths of the use of the mouse
--

vim.keymap.set({'n', 'v', 'i', 'c'}, '<2-LeftMouse>', '<Nop>', {silent = true, desc = "Double-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<2-RightMouse>', '<Nop>', {silent = true, desc = "Double-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<2-MiddleMouse>', '<Nop>', {silent = true, desc = "Double-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<3-LeftMouse>', '<Nop>', {silent = true, desc = "Triple-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<3-RightMouse>', '<Nop>', {silent = true, desc = "Triple-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<3-MiddleMouse>', '<Nop>', {silent = true, desc = "Triple-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<4-LeftMouse>', '<Nop>', {silent = true, desc = "Quad-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<4-RightMouse>', '<Nop>', {silent = true, desc = "Quad-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<4-MiddleMouse>', '<Nop>', {silent = true, desc = "Quad-click disabled"})
vim.keymap.set({'n', 'v', 'i', 'c'}, '<MiddleMouse>', '<Nop>', {silent = true, desc = "Middle click disabled"})

-- remap esc to jj as well
vim.keymap.set("i", "jj", "<Esc>", { noremap = true, silent = true })
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10

-- Easy access to painful symbols using new CapsLock->Ctrl setup
-- Opening pairs (left hand)
vim.keymap.set('i', '<C-g>', '{', {desc = "Insert {"})   -- g for brace
vim.keymap.set('i', '<C-b>', '[', {desc = "Insert ["})   -- b for bracket
vim.keymap.set('i', '<C-v>', '(', {desc = "Insert ("})   -- v for paren

-- Closing pairs (right hand)
vim.keymap.set('i', '<C-l>', '}', {desc = "Insert }"})   -- l for brace
vim.keymap.set('i', '<C-n>', ']', {desc = "Insert ]"})   -- ; for bracket
vim.keymap.set('i', '<C-j>', ')', {desc = "Insert )"})   -- j for paren

-- Operators
vim.keymap.set('i', '<C-k>', '+', {desc = "Insert +"})   -- k for plus
vim.keymap.set('i', '<C-f>', '=', {desc = "Insert ="})   -- f for equal
vim.keymap.set('i', '<C-d>', '_', {desc = "Insert _"})   -- d for underscore
vim.keymap.set('i', '<C-u>', '|', {desc = "Insert |"})   -- u for pipe

-- Toggle dev keyboard layout (calls command from map_nuance to set CAPS_LOCK to new stuff)
vim.keymap.set('n', '<F12>', ':ToggleDevKeys<CR>', {desc = "Toggle dev keyboard layout"})

--
-- schmove zone
--

-- Fast vertical movement (amplify ; and l)
vim.keymap.set('n', 'w', '10j', {desc = "Jump 10 lines down"})
vim.keymap.set('n', 'e', '10k', {desc = "Jump 10 lines up"})

-- Line start/end (one key away from home)
vim.keymap.set('n', 'h', '^', {desc = "First non-whitespace"})
--vim.keymap.set('n', "'", '$', {desc = "End of line"})

-- Block/paragraph jumping
vim.keymap.set('n', 'n', '}', {desc = "Next block"})
vim.keymap.set('n', 'm', '{', {desc = "Previous block"})

--
-- The VULKAN MODE MAPPING
--

local vulkan_mode_active = false

-- Create function for statusline
_G.get_vulkan_mode = function()
    return vulkan_mode_active and "ON" or "OFF"
end

local function exit_vulkan_mode(also_exit_insert)
    if not vulkan_mode_active then return end
    vulkan_mode_active = false

    -- Remove all Vulkan mappings to restore standard runtime
    for i = string.byte('a'), string.byte('z') do
        local letter = string.char(i)
        pcall(vim.keymap.del, 'i', letter)
    end
    pcall(vim.keymap.del, 'i', ' ')
    pcall(vim.keymap.del, 'i', '<Esc>')
    pcall(vim.keymap.del, 'i', 'jj')

    vim.keymap.set("i", "jj", "<Esc>", { noremap = true, silent = true })

    -- Reset cursor colors
    vim.cmd("set guicursor=n-v-c-sm:block,r-cr-o:hor20")

    if also_exit_insert then
        return '<Esc>'
    else
        return ''
    end
end

local function enter_vulkan_mode()
    if vulkan_mode_active then return end
    vulkan_mode_active = true

    -- Set red cursor after colorscheme loads
    vim.schedule(function()
        vim.cmd("highlight Cursor guibg=red guifg=white ctermbg=red ctermfg=white")
        vim.cmd("highlight lCursor guibg=red guifg=white ctermbg=red ctermfg=white")
        vim.opt.guicursor = "i:block-Cursor/lCursor"
    end)

    for i = string.byte('a'), string.byte('z') do
        local lower = string.char(i)
        local upper = string.char(i - 32)
        vim.keymap.set('i', lower, upper)
    end

    -- Smart space mapping: underscore for word separation, space after commas
    vim.keymap.set('i', ' ', function()
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local char_before = col > 0 and line:sub(col, col) or ""

        if char_before == ',' then
            return ' '  -- Preserve space after comma
        else
            return '_'  -- Underscore for word separation
        end
    end, {expr = true})

    vim.keymap.set('i', '<Esc>', function()
        exit_vulkan_mode(true)
        return '<Esc>'
    end, {expr = true})

    vim.keymap.set('i', 'jj', function()
        exit_vulkan_mode(false)
        return ''
    end, {expr = true})
end

-- Activation keymap
vim.keymap.set('i', 'dk', enter_vulkan_mode, {desc = "Enter Vulkan typing mode"})

--
-- The CONTRACT MODE MAPPING (clone of vulkan with modifications)
--

local contract_mode_active = false

_G.get_contract_mode = function()
    return contract_mode_active and "ON" or "OFF"
end

local function exit_contract_mode(also_exit_insert)
    if not contract_mode_active then return end
    contract_mode_active = false

    -- Remove all contract mappings
    for i = string.byte('a'), string.byte('z') do
        local letter = string.char(i)
        pcall(vim.keymap.del, 'i', letter)
    end
    pcall(vim.keymap.del, 'i', ' ')
    pcall(vim.keymap.del, 'i', ')')
    pcall(vim.keymap.del, 'i', ';')
    pcall(vim.keymap.del, 'i', '<Esc>')
    pcall(vim.keymap.del, 'i', 'jj')

    vim.keymap.set("i", "jj", "<Esc>", { noremap = true, silent = true })

    -- Reset cursor
    vim.cmd("set guicursor=n-v-c-sm:block,r-cr-o:hor20")

    if also_exit_insert then
        return '<Esc>'
    else
        return ''
    end
end

local function enter_contract_mode()
    if contract_mode_active then return end
    contract_mode_active = true

    -- Blue cursor to distinguish from vulkan
    vim.schedule(function()
        vim.cmd("highlight Cursor guibg=blue guifg=white ctermbg=blue ctermfg=white")
        vim.cmd("highlight lCursor guibg=blue guifg=white ctermbg=blue ctermfg=white")
        vim.opt.guicursor = "i:block-Cursor/lCursor"
    end)

    -- Map all lowercase to uppercase
    for i = string.byte('a'), string.byte('z') do
        local lower = string.char(i)
        local upper = string.char(i - 32)
        vim.keymap.set('i', lower, upper)
    end

    -- Space stays as space (no underscore conversion)
    vim.keymap.set('i', ' ', ' ')

    -- Auto-exit on ) or ;
    vim.keymap.set('i', ')', function()
        exit_contract_mode(false)
        return ')'
    end, {expr = true})

    vim.keymap.set('i', ';', function()
        exit_contract_mode(false)
        return ';'
    end, {expr = true})

    -- Manual exit mappings
    vim.keymap.set('i', '<Esc>', function()
        exit_contract_mode(true)
        return '<Esc>'
    end, {expr = true})

    vim.keymap.set('i', 'jj', function()
        exit_contract_mode(false)
        return ''
    end, {expr = true})
end

-- Activation keymap
vim.keymap.set('i', 'fk', enter_contract_mode, {desc = "Enter contract typing mode"})

-- Build and run keybindings
vim.keymap.set("n", "<leader>cc", "<cmd>CompileFile<cr>", { desc = "Compile current file" })
vim.keymap.set("n", "<leader>cr", "<cmd>CompileRun<cr>", { desc = "Compile and run" })
vim.keymap.set("n", "<leader>ca", "<cmd>CompileRunArgs<cr>", { desc = "Run with arguments" })
vim.keymap.set("n", "<leader>co", "<cmd>CompileClose<cr>", { desc = "Close build output" })
