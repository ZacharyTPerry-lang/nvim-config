-- ====================================================================================================
--
--  borders.lua
--
--  Snippet System — Border Generators
--  Produces correctly shaped comment border strings for all three tiers of the comment
--  hierarchy across all supported filetypes. C-family filetypes use asymmetric block comment
--  syntax imposed by the preprocessor. All other filetypes use symmetric single-prefix bars.
--  All borders fill to exactly 100 characters.
--
-- ====================================================================================================

local M = {}

-- ====================================================================================================
--
-- CONSTANTS
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Definition : Line Width
-- ----------------------------------------------------------------------------------------------------

local LINE_WIDTH = 100

-- ====================================================================================================
--
-- INTERNAL UTILITIES
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Repeat Character To Width
-- ----------------------------------------------------------------------------------------------------

local function fill(character, width)
    return string.rep(character, width)
end

-- ----------------------------------------------------------------------------------------------------
-- Operation : Build Symmetric Bar
-- ----------------------------------------------------------------------------------------------------

-- prefix is the full line prefix including trailing space e.g. "# " or "-- " or "! "
local function symmetric_bar(prefix, character)
    local bar_width = LINE_WIDTH - #prefix
    return prefix .. fill(character, bar_width)
end

-- ====================================================================================================
--
-- C-FAMILY BORDERS
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : C File Header
-- ----------------------------------------------------------------------------------------------------

local function c_file_header(name, system, description)
    local open_bar  = "/* " .. fill("*", LINE_WIDTH - 3)
    local close_bar = " * " .. fill("*", LINE_WIDTH - 5) .. "*/"
    return {
        open_bar,
        " *",
        " *  " .. name,
        " *",
        " *  " .. system,
        " *  " .. description,
        " *",
        close_bar,
    }
end

-- ----------------------------------------------------------------------------------------------------
-- Operation : C Section Marker
-- ----------------------------------------------------------------------------------------------------

local function c_section(name)
    local open_bar  = "/* " .. fill("=", LINE_WIDTH - 3)
    local close_bar = " * " .. fill("=", LINE_WIDTH - 5) .. "*/"
    return {
        open_bar,
        " *",
        " * " .. name,
        " *",
        close_bar,
    }
end

-- ----------------------------------------------------------------------------------------------------
-- Operation : C Block Label
-- ----------------------------------------------------------------------------------------------------

local function c_block(bin, label)
    local open_bar  = "/* " .. fill("-", LINE_WIDTH - 3)
    local close_bar = " * " .. fill("-", LINE_WIDTH - 5) .. "*/"
    return {
        open_bar,
        " * " .. bin .. " : " .. label,
        close_bar,
    }
end

-- ====================================================================================================
--
-- SYMMETRIC BORDERS
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Symmetric File Header
-- ----------------------------------------------------------------------------------------------------

local function sym_file_header(prefix, name, system, description)
    local bar = symmetric_bar(prefix, "*")
    return {
        bar,
        prefix:gsub("%s+$", ""),
        prefix .. " " .. name,
        prefix:gsub("%s+$", ""),
        prefix .. " " .. system,
        prefix .. " " .. description,
        prefix:gsub("%s+$", ""),
        bar,
    }
end

-- ----------------------------------------------------------------------------------------------------
-- Operation : Symmetric Section Marker
-- ----------------------------------------------------------------------------------------------------

local function sym_section(prefix, name)
    local bar = symmetric_bar(prefix, "=")
    return {
        bar,
        prefix:gsub("%s+$", ""),
        prefix .. name,
        prefix:gsub("%s+$", ""),
        bar,
    }
end

-- ----------------------------------------------------------------------------------------------------
-- Operation : Symmetric Block Label
-- ----------------------------------------------------------------------------------------------------

local function sym_block(prefix, bin, label)
    local bar = symmetric_bar(prefix, "-")
    return {
        bar,
        prefix .. bin .. " : " .. label,
        bar,
    }
end

-- ====================================================================================================
--
-- PUBLIC INTERFACE
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Definition : Filetype Prefix Map
-- ----------------------------------------------------------------------------------------------------

local prefix_map = {
    c          = nil,
    cpp        = nil,
    make       = "# ",
    fortran    = "! ",
    markdown   = "## ",
    text       = "## ",
    lua        = "-- ",
}

local c_family = { c = true, cpp = true }

-- ----------------------------------------------------------------------------------------------------
-- Interface : Get Borders For Filetype
-- ----------------------------------------------------------------------------------------------------

M.get = function(filetype)
    if c_family[filetype] then
        return {
            file_header = c_file_header,
            section     = c_section,
            block       = c_block,
        }
    end

    local prefix = prefix_map[filetype] or "# "

    return {
        file_header = function(name, system, description)
            return sym_file_header(prefix, name, system, description)
        end,
        section = function(name)
            return sym_section(prefix, name)
        end,
        block = function(bin, label)
            return sym_block(prefix, bin, label)
        end,
    }
end

return M
