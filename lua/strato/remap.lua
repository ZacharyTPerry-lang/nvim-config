vim.g.mapleader =  " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Normal mode
vim.keymap.set("n", "<Tab>", ">>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-Tab>", "<<", { noremap = true, silent = true })

-- Visual mode (with reselect)
vim.keymap.set("v", "<Tab>", ">gv", { noremap = true, silent = true })
vim.keymap.set("v", "<S-Tab>", "<gv", { noremap = true, silent = true })

-- Insert mode (simulate normal mode indentation)
vim.keymap.set("i", "<Tab>", "<C-o>>>", { noremap = true, silent = true })
vim.keymap.set("i", "<S-Tab>", "<C-o><<", { noremap = true, silent = true })

--(Normal mode newline and prev line)
vim.keymap.set("n", "<S-CR>", "o<Esc>", { desc = "Insert blank line below" })
vim.keymap.set("n", "<Tab><CR>", "O<Esc>", { desc = "Insert blank line above" })

