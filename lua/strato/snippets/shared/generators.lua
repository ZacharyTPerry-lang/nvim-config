-- ====================================================================================================
--
--  generators.lua
--
--  Snippet System — Snippet Generators
--  Factory functions that produce LuaSnip snippet objects for each filetype. Consumes
--  vocabulary.lua for term lists and borders.lua for border shapes. Each filetype snippet
--  file calls these generators rather than constructing snippets directly.
--
-- ====================================================================================================

local ls        = require("luasnip")
local t         = ls.text_node
local i         = ls.insert_node
local f         = ls.function_node
local fmt       = require("luasnip.extras.fmt").fmt
local borders   = require("strato.snippets.shared.borders")
local vocab     = require("strato.snippets.shared.vocabulary")

local M = {}


-- ====================================================================================================
--
-- INTERNAL UTILITIES
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Filename From Buffer
-- ----------------------------------------------------------------------------------------------------

local function current_filename()
    return vim.fn.expand("%:t")
end


-- ----------------------------------------------------------------------------------------------------
-- Operation : Lines To Text Nodes
-- ----------------------------------------------------------------------------------------------------

-- Converts a table of strings into a single text node with newlines between each line.
local function lines_to_t(line_table)
    return t(line_table)
end


-- ====================================================================================================
--
-- FILE HEADER GENERATOR
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Make File Header Snippet
-- ----------------------------------------------------------------------------------------------------

-- Tabstops:
--   1 — system and subsystem line  e.g. "Error System — Layer 0"
--   2 — description line
-- Filename is auto-populated from the current buffer name.

M.make_file_header = function(filetype)
    local b = borders.get(filetype)

    if filetype == "c" or filetype == "cpp" then
        return ls.snippet(
            { trig = "fh", desc = "File header — title page comment block" },
            {
                t({ "/* " .. string.rep("*", 97) }),
                t({ "", " *", " *  " }),
                f(function() return { current_filename() } end, {}),
                t({ "", " *", " *  " }),
                i(1, "System — Subsystem"),
                t({ "", " *  " }),
                i(2, "Description."),
                t({ "", " *", " * " .. string.rep("*", 96) .. "*/" }),
            }
        )
    end

    -- TODO: prefix logic below is duplicated across all three generators instead of
    -- delegating to borders.lua. Refactor to call borders.get(filetype) cleanly once
    -- the basic snippet shape is confirmed working.
    local p = filetype == "make" and "# "
           or filetype == "fortran" and "! "
           or filetype == "lua" and "-- "
           or "## "
    local bar = p .. string.rep("*", 100 - #p)
    local blank = p:gsub("%s+$", "")

    return ls.snippet(
        { trig = "fh", desc = "File header — title page comment block" },
        {
            t({ bar, blank, p .. " " }),
            f(function() return { current_filename() } end, {}),
            t({ "", blank, p .. " " }),
            i(1, "System — Subsystem"),
            t({ "", p .. " " }),
            i(2, "Description."),
            t({ "", blank, bar }),
        }
    )
end


-- ====================================================================================================
--
-- SECTION MARKER GENERATOR
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Make Section Marker Snippet
-- ----------------------------------------------------------------------------------------------------

-- Tabstops:
--   1 — section name, all caps by convention, use Vulkan mode

M.make_section_marker = function(filetype)
    if filetype == "c" or filetype == "cpp" then
        return ls.snippet(
            { trig = "sm", desc = "Section marker — chapter break comment block" },
            {
                t({ "/* " .. string.rep("=", 97) }),
                t({ "", " *", " * " }),
                i(1, "SECTION NAME"),
                t({ "", " *", " * " .. string.rep("=", 95) .. "*/" }),
            }
        )
    end

    -- TODO: same prefix duplication as file header generator. See refactor note above.
    local p = filetype == "make" and "# "
           or filetype == "fortran" and "! "
           or filetype == "lua" and "-- "
           or "## "
    local bar   = p .. string.rep("=", 100 - #p)
    local blank = p:gsub("%s+$", "")

    return ls.snippet(
        { trig = "sm", desc = "Section marker — chapter break comment block" },
        {
            t({ bar, blank, p }),
            i(1, "SECTION NAME"),
            t({ "", blank, bar }),
        }
    )
end


-- ====================================================================================================
--
-- BLOCK LABEL GENERATOR
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Make Block Label Snippet
-- ----------------------------------------------------------------------------------------------------

-- Tabstops:
--   1 — bin name, drawn from vocabulary, use contract mode for caps
--   2 — label name, plain text

M.make_block_label = function(filetype)
    if filetype == "c" or filetype == "cpp" then
        return ls.snippet(
            { trig = "bl", desc = "Block label — typed specimen comment block" },
            {
                t({ "/* " .. string.rep("-", 97) }),
                t({ "", " * " }),
                i(1, "Bin"),
                t(" : "),
                i(2, "Name"),
                t({ "", " * " .. string.rep("-", 95) .. "*/" }),
            }
        )
    end

    -- TODO: same prefix duplication as file header generator. See refactor note above.
    local p = filetype == "make" and "# "
           or filetype == "fortran" and "! "
           or filetype == "lua" and "-- "
           or "## "
    local bar = p .. string.rep("-", 100 - #p)

    return ls.snippet(
        { trig = "bl", desc = "Block label — typed specimen comment block" },
        {
            t({ bar, p }),
            i(1, "Bin"),
            t(" : "),
            i(2, "Name"),
            t({ "", bar }),
        }
    )
end


-- ====================================================================================================
--
-- PUBLIC INTERFACE
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Build All Snippets For Filetype
-- ----------------------------------------------------------------------------------------------------

M.build = function(filetype)
    return {
        M.make_file_header(filetype),
        M.make_section_marker(filetype),
        M.make_block_label(filetype),
    }
end


return M
