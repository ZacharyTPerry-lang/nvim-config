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

-- Assembly viewer keybinds
vim.keymap.set("n", "<leader>at", function() vim.cmd("AsmViewToggle") end, { desc = "Toggle Assembly View" })
vim.keymap.set("n", "<leader>al", function() vim.cmd("AsmViewMode") end, { desc = "Toggle PTX/SASS View" })

-- Unmap a it was causing issues
vim.keymap.set('n', 'a', '<nop>', { desc = 'Disabled (use I for insert)' })
vim.keymap.set('n', 'v', '<nop>', {desc = "Visual mode disabled"})
vim.keymap.set('n', 'V', '<nop>', {desc = "Visual line mode disabled"})

-- Left-to-right ordering on home row
vim.keymap.set('n', 'j', 'h', {desc = "Move left"})   -- j = left
vim.keymap.set('n', 'k', 'j', {desc = "Move down"})   -- k = down
vim.keymap.set('n', 'l', 'k', {desc = "Move up"})     -- l = up
vim.keymap.set('n', ';', 'l', {desc = "Move right"})  -- ; = right

--
-- Del remaps kinda important
--

vim.keymap.set('i', '<C-e>', '<Del>', {desc = "Delete forward"})

-- Shoot double click into visual mode specifically does not work
vim.keymap.set({'n', 'v', 'i'}, '<2-LeftMouse>', '<Nop>', {silent = true})

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
vim.keymap.set('n', "'", '$', {desc = "End of line"})

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

-- Build and run keybindings
vim.keymap.set("n", "<leader>cc", "<cmd>CompileFile<cr>", { desc = "Compile current file" })
vim.keymap.set("n", "<leader>cr", "<cmd>CompileRun<cr>", { desc = "Compile and run" })
vim.keymap.set("n", "<leader>ca", "<cmd>CompileRunArgs<cr>", { desc = "Run with arguments" })
vim.keymap.set("n", "<leader>co", "<cmd>CompileClose<cr>", { desc = "Close build output" })
