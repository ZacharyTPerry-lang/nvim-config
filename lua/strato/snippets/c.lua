-- ====================================================================================================
--
--  c.lua
--
--  Snippet System — C Filetype Snippets
--  Registers all snippets for C source and header files. Delegates snippet construction
--  to generators.lua. Add new C-specific snippets below the generated set.
--
-- ====================================================================================================

local generators = require("strato.snippets.shared.generators")

-- ====================================================================================================
--
-- GENERATED SNIPPETS
--
-- ====================================================================================================

-- ----------------------------------------------------------------------------------------------------
-- Operation : Build And Return C Snippet Set
-- ----------------------------------------------------------------------------------------------------

return generators.build("c")
