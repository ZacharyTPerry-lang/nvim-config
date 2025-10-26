-- LSP Profile management file by Zachary Perry

local M = {}

--
-- Block one all the functions for functionality
--

local LSP_BASE_PATH = vim.fn.stdpath("config") .. "/lua/strato/lsp"

function M.get_available_profiles(lang)
    local lang_path = LSP_BASE_PATH .. "/" .. lang

    if vim.fn.isdirectory(lang_path) == 0 then
        return {}
    end

    local profiles = {}
    local handle = vim.loop.fs_scandir(lang_path)
    if handle then
        while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then break end
            if type == "directory" then
                table.insert(profiles, name)
            end
        end
    end

    table.sort(profiles)
    return profiles
end

function M.get_profile_path(lang, profile_name)
    return LSP_BASE_PATH .. "/" .. lang .. "/" .. profile_name
end

function M.profile_exists(lang, profile_name)
    local path = M.get_profile_path(lang, profile_name)
    return vim.fn.isdirectory(path) == 1
end

function M.find_lsp_profile_file(root_dir)
    if not root_dir then return nil end

    local profile_file = root_dir .. "/.lsp-profile"
    if vim.fn.filereadable(profile_file) == 1 then
        return profile_file
    end

    return nil
end

function M.parse_profile_file(filepath)
    local profiles = {}

    local file = io.open(filepath, "r")
    if not file then return profiles end

    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        if line ~= "" and not line:match("^#") then
            local lang, profile = line:match("^(%w+):(%w+)$")
            if lang and profile then
                profiles[lang] = profile
            end
        end
    end

    file:close()
    return profiles
end

function M.get_profile_for_buffer(bufnr, lang)
    local cached = vim.b[bufnr].lsp_profile
    if cached then
        return cached
    end

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local root_dir = nil

    for _, client in ipairs(clients) do
        if client.config.root_dir then
            root_dir = client.config.root_dir
            break
        end
    end

    local default_profile = "standard"

    if not root_dir then
        return default_profile
    end

    local profile_file = M.find_lsp_profile_file(root_dir)
    if not profile_file then
        return default_profile
    end

    local profiles = M.parse_profile_file(profile_file)
    local requested_profile = profiles[lang]

    if not requested_profile then
        return default_profile
    end

    if not M.profile_exists(lang, requested_profile) then
        local available = M.get_available_profiles(lang)
        vim.notify(
            string.format(
                "LSP Profile Error: '%s' not found for %s\nAvailable profiles: %s\nUsing default: %s",
                requested_profile,
                lang,
                table.concat(available, " ,"),
                default_profile
            ),
            vim.log.levels.ERROR
        )
        return default_profile
    end

    return requested_profile
end

--
-- Subsection for project tracking and processing

local project_cache = {}

function M.is_safe_project_root(root_dir)
    if not root_dir then return false end

    if vim.fn.filewritable(root_dir) ~= 2 then return false end

    local depth = select(2, root_dir:gsub("/", ""))
    if depth < 4 then return false end

    return true
end

function M.read_template(lang, profile)
    local template_path = M.get_profile_path(lang, profile) .. "/.clangd"

    if vim.fn.filereadable(template_path) == 0 then
        return nil
    end

    local file = io.open(template_path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    return content
end

function M.is_our_clangd(filepath)
    if vim.fn.filereadable(filepath) == 0 then
        return false, nil
    end

    local file = io.open(filepath, "r")
    if not file then return false, nil end

    local first_line = file:read("*l")
    file:close()

    if not first_line then return false, nil end

    local profile = first_line:match("^# NVIM LSP PROFILES %- (%w+) %- TEMPLATE")
    if profile then
        return true, profile
    end

    return false, nil
end

function M.ensure_clangd_config(root_dir, lang, profile)
    if not M.is_safe_project_root(root_dir) then
        return false
    end

    local template = M.read_template(lang, profile)
    if not template then
        vim.notify(
            string.format("Template not found: %s/%s", lang, profile),
            vim.log.levels.ERROR
        )
        return false
    end

    local clangd_path = root_dir .. "/.clangd"
    local is_ours, existing_profile = M.is_our_clangd(clangd_path)

    if vim.fn.filereadable(clangd_path) == 1 and not is_ours then
        return false
    end

    local should_regenerate = false

    if vim.fn.filereadable(clangd_path) == 0 then
        should_regenerate = true
    elseif is_ours and existing_profile ~=profile then
        should_regenerate = true
    elseif is_ours then
        local template_path = M.get_profile_path(lang, profile) .. "/.clangd"
        local template_time = vim.fn.getftime(template_path)
        local config_time = vim.fn.getftime(clangd_path)

        if template_time > config_time then
            should_regenerate = true
        end
    end

    if should_regenerate then
        local success, err = pcall(function()
            local file = io.open(clangd_path, "w")
            if not file then
                error("Failed to open file for writing")
            end
            file:write(template)
            file:close()
        end)

        if not success then
            vim.notify(
                string.format("Failed to write .clangd: %s", err),
                vim.log.levels.ERROR
            )
            return false
        end
    end

    return true
end

function M.cleanup_orphaned_config(root_dir)
    local clangd_path = root_dir .. "/.clangd"
    local is_ours, _ = M.is_our_clangd(clangd_path)

    if is_ours then
        local profile_file = M.find_lsp_profile_file(root_dir)
        if not profile_file then
            pcall(function()
                os.remove(clangd_path)
        end)
    end
end
end


function M.get_or_create_project_cache(root_dir)
    if not project_cache[root_dir] then
        project_cache[root_dir] = {
            profile = nil,
            checked = false,
            timestamp = 0
        }
    end
    return project_cache[root_dir]
end

function M.detect_header_language(root_dir, bufnr)
    local ft = vim.bo[bufnr].filetype
    local filename = vim.api.nvim_buf_get_name(bufnr)

    if not filename:match("%.h$") then
        return ft
    end

    local basename = filename:match("^(.*)%.h$")
    if basename then
        -- Check for .c file first
        if vim.fn.filereadable(basename .. ".c") == 1 then
            return "c"
        end
        -- Then check for .cpp
        if vim.fn.filereadable(basename .. ".cpp") == 1 then
            return "cpp"
        end
        -- Also check .cc and .cxx variants
        if vim.fn.filereadable(basename .. ".cc") == 1 or
           vim.fn.filereadable(basename .. ".cxx") == 1 then
            return "cpp"
        end
    end

    local profile_file = M.find_lsp_profile_file(root_dir)
    if profile_file then
        local parsed = M.parse_profile_file(profile_file)
        if parsed.c and not parsed.cpp then
            return "c"
        end
        if parsed.cpp and not parsed.c then
            return "cpp"
        end
    end

    -- Default to C for headers if no other indication it is doomed
    return "c"
end

--
-- Block two the user command functions
--

function M.setup_command()
    vim.api.nvim_create_user_command("LspProfiles", function(opts)
        local lang = opts.args

        if lang == "" then
            local languages = {}
            local handle = vim.loop.fs_scandir(LSP_BASE_PATH)
            if handle then
                while true do
                    local name, type = vim.loop.fs_scandir_next(handle)
                    if not name then break end
                    if type == "directory" then
                        table.insert(languages, name)
                    end
                end
            end

            if #languages == 0 then
                vim.notify("No LSP profiles configured", vim.log.levels.INFO)
                return
            end

            table.sort(languages)
            vim.notify(
                "Available languages: " .. table.concat(languages, ", ") .. "\nUse :LspProfiles <language> to see profiles",
                vim.log.levels.INFO
            )
            return
        end

        -- Handle specific language
        local profiles = M.get_available_profiles(lang)

        if #profiles == 0 then
            vim.notify(
                string.format("No profiles found for language: %s", lang),
                vim.log.levels.WARN
            )
            return
        end

        local current_profile = vim.b.lsp_profile
        local lines = {string.format("Available %s profiles:", lang)}

        for _, profile in ipairs(profiles) do
            if profile == current_profile then
                table.insert(lines, "  • " .. profile .. " (active)")
            else
                table.insert(lines, "  • " .. profile)
            end
        end

        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end, {
        nargs = "?",
        complete = function()
            local languages = {}
            local handle = vim.loop.fs_scandir(LSP_BASE_PATH)
            if handle then
                while true do
                    local name, type = vim.loop.fs_scandir_next(handle)
                    if not name then break end
                    if type == "directory" then
                        table.insert(languages, name)
                    end
                end
            end
            table.sort(languages)
            return languages
        end,
        desc = "Show available LSP profiles"
    })

    -- second command :LspProfileReload - forces a regeneration of the releated clangd file
    vim.api.nvim_create_user_command("LspProfileReload", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })

        if #clients == 0 then
            vim.notify("No LSP client attatched to the current buffer", vim.log.levels.WARN)
            return
        end

        local root_dir = nil
        for _, client in ipairs(clients) do
            if client.name == "clangd" and client.config.root_dir then
                root_dir = client.config.root_dir
                break
            end
        end

        if not root_dir then
            vim.notify("No clang root directory found", vim.log.levels.WARN)
            return
        end

        --Clear the cache right here
        project_cache[root_dir] = nil

        --clear the buffer
        vim.b[bufnr].lsp_profile = nil

        -- get lang and attempt a regenerate
        local detected_ft = M.detect_header_language(root_dir, bufnr)
        local lang_map = { c = "c", cpp = "cpp", opencl = "opencl", objc = "c", objcpp = "cpp" }
        local lang = lang_map[detected_ft] or "c"
        local profile = M.get_profile_for_buffer(bufnr, lang)
        local success = M.ensure_clangd_config(root_dir, lang, profile)

        if success then
            vim.notify(
                string.format("Reloaded profile: %s (%s)", profile, lang),
                vim.log.levels.INFO
            )
            -- Pull start the LSP
            vim.cmd("LspRestart clangd")
        else
            vim.notify("Failed to reload profile", vim.log.levels.ERROR)
        end
    end, {
        desc = "Force regenerate clangd for current project"
        }
    )

    -- Command :LspProfileClean - remove an autogenerated clangd
    vim.api.nvim_create_user_command("LspProfileClean", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })

        if #clients == 0 then
            vim.notify("No LSP client attatched to current buffer", vim.log.levels.WARN)
            return
        end

        local root_dir = nil
        for _, client in ipairs(clients) do
            if client.name == "clangd" and client.config.root_dir then
                root_dir = client.config.root_dir
                break
            end
        end

        if not root_dir then
            vim.notify("No clangd root directory found", vim.log.levels.WARN)
            return
        end

        local clangd_path = root_dir .. "/.clangd"
        local is_ours, profile = M.is_our_clangd(clangd_path)

        if not is_ours then
            vim.notify("clangd not generated by profile system", vim.log.levels.WARN)
            return
        end

        --kill it
        local success = pcall(function()
            os.remove(clangd_path)
        end)

        if success then
            project_cache[root_dir] = nil
            vim.notify("Removed generated clangd", vim.log.levels.INFO)
        else
            vim.notify("Failed to remove clangd", vim.log.levels.ERROR)
        end
    end, {
        desc = "Remove generated clangd from current project"
        }
    )

    -- command : LspProfileInfo - LspInfo but better
    vim.api.nvim_create_user_command("LspProfileInfo", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })

        if #clients == 0 then
            vim.notify("No LSP client attatched to current buffer", vim.log.levels.WARN)
            return
        end

        local root_dir = nil
        for _, client in ipairs(clients) do
            if client.name == "clangd" and client.config.root_dir then
                root_dir = client.config.root_dir
                break
            end
        end

        if not root_dir then
            vim.notify("No clangd root directory found", vim.log.levels.WARN)
            return
        end

        local detected_ft = M.detect_header_language(root_dir, bufnr)
        local lang_map = { c = "c", cpp = "cpp", opencl = "opencl", objc = "c", objcpp = "cpp" }
        local lang = lang_map[detected_ft] or "c"

        local profile = vim.b[bufnr].lsp_profile or "unknown"

        local clangd_path = root_dir .. "/.clangd"
        local clangd_status = "does not exist"
        local is_ours, existing_profile = M.is_our_clangd(clangd_path)

        if vim.fn.filereadable(clangd_path) == 1 then
            if is_ours then
                clangd_status = string.format("generated (profile: %s)", existing_profile)
                local timestamp = vim.fn.getftime(clangd_path)
                local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
                clangd_status = clangd_status .. string.format("\n Last Modified: %s", date)
            else
                clangd_status = "user-mangaged (not made by the profile system)"
            end
        end

        local template_path = M.get_profile_path(lang, profile) .. "/.clangd"
        local template_exists = vim.fn.filereadable(template_path) == 1

        local info = {
            "LSP Profile Information:",
            "",
            " Language: " .. lang,
            " Profile: " .. profile,
            " Project Root: " .. root_dir,
            " Template Path: " .. template_path,
            " Template Exists: " .. (template_exists and "yes" or "no"),
            " .clangd status: " .. clangd_status,
        }

        vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
    end, {
        desc = "Show detailed LSP profile information"
        }
    )
end

return M

