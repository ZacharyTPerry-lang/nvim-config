-- ====================================================================================================
--
--  highlights.lua
--
--  Snippet System — Comment Hierarchy Highlights
--  Minimal shim. Four highlight groups for the three-tier comment border system.
--  Groups link to existing semantic roles so colorscheme switches do not break hierarchy.
--  Replace link targets here when a more permanent design is decided.
--
-- ====================================================================================================

local M = {}

-- ====================================================================================================
--
-- HIGHLIGHT DEFINITIONS
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Apply Highlight Groups
-- ----------------------------------------------------------------------------------------------------

M.setup = function()

    -- File header border  /* **** */
    -- Links to Title — bright, prominent, every theme defines it distinctly.
    vim.api.nvim_set_hl(0, "StratoFileHeader", { link = "Title" })

    -- Section border  /* ==== */
    -- Links to Statement — themed color, not grey, distinct from comments.
    vim.api.nvim_set_hl(0, "StratoSection", { link = "Statement" })

    -- Block label border  /* ---- */
    -- Links to Comment — deliberately recessive, metadata not content.
    vim.api.nvim_set_hl(0, "StratoBlock", { link = "Comment" })

    -- Block label name line  /* Bin : Name */
    -- Links to Special — slightly lifted from pure comment grey, readable as a label.
    vim.api.nvim_set_hl(0, "StratoBlockName", { link = "Special" })

end

return M
