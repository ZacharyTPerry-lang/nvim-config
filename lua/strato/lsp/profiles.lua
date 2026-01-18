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

-- Helper to get config filename for a language
function M.get_config_filename(lang)
    if lang == "vhdl" then
        return ".ghdl-ls.json"
    else
        return ".clangd"
    end
end

function M.read_template(lang, profile)
    local config_filename = M.get_config_filename(lang)
    local template_path = M.get_profile_path(lang, profile) .. "/" .. config_filename

    if vim.fn.filereadable(template_path) == 0 then
        return nil
    end

    local file = io.open(template_path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    return content
end

function M.is_our_config(filepath, lang)
    if vim.fn.filereadable(filepath) == 0 then
        return false, nil
    end

    local file = io.open(filepath, "r")
    if not file then return false, nil end

    local first_line = file:read("*l")

    if lang == "vhdl" then
        -- For VHDL, check for JSON comment at start
        -- Look for: {"_comment": "NVIM LSP PROFILES - standard - TEMPLATE",
        local content = first_line
        -- Read more if needed to get the full JSON structure start
        local line2 = file:read("*l")
        if line2 then content = content .. "\n" .. line2 end

        file:close()

        -- Extract profile from JSON comment
        local profile = content:match('"_comment":%s*"NVIM LSP PROFILES %- (%w+) %- TEMPLATE"')
        return profile ~= nil, profile
    else
        -- For C/C++, use existing logic
        local profile = first_line:match("^# NVIM LSP PROFILES %- (%w+) %- TEMPLATE")

        if not profile then
            file:close()
            return false, nil
        end

        -- Read until we hit the dynamic marker or EOF
        local template_section = first_line .. "\n"
        for line in file:lines() do
            template_section = template_section .. line .. "\n"
            if line:match("^# NVIM LSP PROFILES %- DYNAMIC SECTION START") then
                break
            end
        end

        file:close()
        return true, profile, template_section
    end
end

function M.extract_vendor_paths_from_makefile(root_dir)
    local makefile = root_dir .. "/Makefile"
    if vim.fn.filereadable(makefile) == 0 then
        -- Try lowercase version
        makefile = root_dir .. "/makefile"
        if vim.fn.filereadable(makefile) == 0 then
            return {}
        end
    end

    local vendor_paths = {}
    local seen = {}

    local file = io.open(makefile, "r")
    if not file then return {} end

    for line in file:lines() do
        -- Look for -I flags in CFLAGS lines
        if line:match("CFLAGS") then
            -- Extract all -I paths from the line
            for include_path in line:gmatch("-I(%S+)") do
                if not seen[include_path] then
                    seen[include_path] = true
                    table.insert(vendor_paths, include_path)
                end
            end
        end

        -- Also look for := assignments with vendor paths (for other cases)
        local var_name, path = line:match("^%s*(%w+)%s*:=%s*(.-)%s*$")
        if path and path:match("vendor/") then
            -- Extract the vendor directory part
            local vendor_dir = path:match("(vendor/[^/]+)")
            if vendor_dir and not seen[vendor_dir] then
                -- Only add if it looks like an include directory
                if vim.fn.isdirectory(root_dir .. "/" .. vendor_dir) == 1 then
                    -- Check if it has header files
                    local has_headers = false
                    local headers = vim.fn.glob(root_dir .. "/" .. vendor_dir .. "/*.h", false, true)
                    if #headers > 0 then
                        has_headers = true
                    end
                    -- Also check include subdirectory
                    headers = vim.fn.glob(root_dir .. "/" .. vendor_dir .. "/include/*.h", false, true)
                    if #headers > 0 then
                        has_headers = true
                    end

                    if has_headers and not seen[vendor_dir] then
                        seen[vendor_dir] = true
                        table.insert(vendor_paths, vendor_dir)
                    end
                end
            end
        end
    end

    file:close()

    return vendor_paths
end

function M.ensure_ghdl_config(root_dir, profile)
    if not M.is_safe_project_root(root_dir) then
        return false
    end

    local template = M.read_template("vhdl", profile)
    if not template then
        vim.notify(
            string.format("Template not found: vhdl/%s", profile),
            vim.log.levels.ERROR
        )
        return false
    end

    local ghdl_path = root_dir .. "/.ghdl-ls.json"
    local is_ours, existing_profile = M.is_our_config(ghdl_path, "vhdl")

    if vim.fn.filereadable(ghdl_path) == 1 and not is_ours then
        return false
    end

    local should_regenerate = false

    if vim.fn.filereadable(ghdl_path) == 0 then
        should_regenerate = true
    elseif is_ours and existing_profile ~= profile then
        should_regenerate = true
    elseif is_ours then
        local template_path = M.get_profile_path("vhdl", profile) .. "/.ghdl-ls.json"
        local template_time = vim.fn.getftime(template_path)
        local config_time = vim.fn.getftime(ghdl_path)

        if template_time > config_time then
            should_regenerate = true
        end

        -- Also check if Makefile changed (VHDL projects might have vendor IP)
        local makefile_time = vim.fn.getftime(root_dir .. "/Makefile")
        if makefile_time == -1 then
            makefile_time = vim.fn.getftime(root_dir .. "/makefile")
        end
        if makefile_time > config_time then
            should_regenerate = true
        end
    end

    if should_regenerate then
        -- For VHDL, we might want to add vendor libraries dynamically
        -- For now, just write the template
        local final_content = template

        local success, err = pcall(function()
            local file = io.open(ghdl_path, "w")
            if not file then
                error("Failed to open file for writing")
            end
            file:write(final_content)
            file:close()
        end)

        if not success then
            vim.notify(
                string.format("Failed to write .ghdl-ls.json: %s", err),
                vim.log.levels.ERROR
            )
            return false
        end
    end

    return true
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
    local is_ours, existing_profile, template_section = M.is_our_config(clangd_path, lang)

    if vim.fn.filereadable(clangd_path) == 1 and not is_ours then
        return false
    end

    local should_regenerate = false

    if vim.fn.filereadable(clangd_path) == 0 then
        should_regenerate = true
    elseif is_ours and existing_profile ~= profile then
        should_regenerate = true
    elseif is_ours then
        -- Check if template changed
        local template_path = M.get_profile_path(lang, profile) .. "/.clangd"
        local template_time = vim.fn.getftime(template_path)
        local config_time = vim.fn.getftime(clangd_path)

        if template_time > config_time then
            should_regenerate = true
        end

        -- Also check if Makefile changed
        local makefile_time = vim.fn.getftime(root_dir .. "/Makefile")
        if makefile_time == -1 then
            makefile_time = vim.fn.getftime(root_dir .. "/makefile")
        end
        if makefile_time > config_time then
            should_regenerate = true
        end

        -- Check if template content differs from what we have
        if template_section and template ~= template_section:sub(1, -2) then  -- Remove trailing newline for comparison
            should_regenerate = true
        end
    end

    if should_regenerate then
        -- Build final content
        local final_content = template

        -- Check for vendor dependencies in Makefile
        local makefile = root_dir .. "/Makefile"
        if vim.fn.filereadable(makefile) == 0 then
            makefile = root_dir .. "/makefile"
        end
        if vim.fn.filereadable(makefile) == 1 then
            local vendor_paths = M.extract_vendor_paths_from_makefile(root_dir)
            if #vendor_paths > 0 then
                -- We need to inject the includes into the existing CompileFlags section
                -- Find the CompileFlags: Add: section and append to it
                local lines = {}
                for line in template:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end

                -- Find where to insert (after the last Add: item)
                local insert_index = nil
                local in_compile_flags_add = false
                for i, line in ipairs(lines) do
                    if line:match("^CompileFlags:") then
                        in_compile_flags_add = false
                    elseif line:match("^%s+Add:") then
                        in_compile_flags_add = true
                    elseif in_compile_flags_add and line:match("^%s+%s+%-") then
                        -- This is an item in the Add list
                        insert_index = i
                    elseif in_compile_flags_add and not line:match("^%s+%s+") then
                        -- We've left the Add section
                        break
                    end
                end

                if insert_index then
                    -- Add dynamic section marker and vendor includes
                    table.insert(lines, insert_index + 1, "    # NVIM LSP PROFILES - DYNAMIC VENDOR INCLUDES")
                    for j, path in ipairs(vendor_paths) do
                        -- Make paths absolute from project root
                        table.insert(lines, insert_index + 1 + j, "    - -I" .. root_dir .. "/" .. path)
                    end
                    final_content = table.concat(lines, "\n")
                else
                    -- Fallback: append as before if we can't find the right spot
                    final_content = template .. "\n# NVIM LSP PROFILES - DYNAMIC SECTION START\n"
                    final_content = final_content .. "# Auto-detected vendor includes from Makefile\n"
                    final_content = final_content .. "CompileFlags:\n  Add:\n"

                    for _, path in ipairs(vendor_paths) do
                        final_content = final_content .. "    - -I" .. path .. "\n"
                    end
                end
            end
        end

        local success, err = pcall(function()
            local file = io.open(clangd_path, "w")
            if not file then
                error("Failed to open file for writing")
            end
            file:write(final_content)
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

-- Main dispatcher function
function M.ensure_lsp_config(root_dir, lang, profile)
    if lang == "vhdl" then
        return M.ensure_ghdl_config(root_dir, profile)
    else
        -- C/C++/OpenCL use clangd
        return M.ensure_clangd_config(root_dir, lang, profile)
    end
end

function M.cleanup_orphaned_config(root_dir, lang)
    local config_filename = M.get_config_filename(lang)
    local config_path = root_dir .. "/" .. config_filename
    local is_ours, _ = M.is_our_config(config_path, lang)

    if is_ours then
        local profile_file = M.find_lsp_profile_file(root_dir)
        if not profile_file then
            pcall(function()
                os.remove(config_path)
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

    -- Default to C for headers if no other indication
    return "c"
end

-- Helper to detect active LSP client and language
function M.detect_active_lsp_for_buffer(bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return nil, nil, nil
    end

    -- Priority order for known LSPs
    local lsp_priority = {
        clangd = { langs = {"c", "cpp", "opencl", "objc", "objcpp"} },
        ghdl_ls = { langs = {"vhdl"} }
    }

    for _, client in ipairs(clients) do
        local client_info = lsp_priority[client.name]
        if client_info and client.config.root_dir then
            -- Determine language based on filetype
            local ft = vim.bo[bufnr].filetype

            -- Special handling for headers
            if ft == "c" or ft == "cpp" then
                local detected_ft = M.detect_header_language(client.config.root_dir, bufnr)
                ft = detected_ft
            end

            -- Map filetype to our language
            local lang_map = {
                c = "c",
                cpp = "cpp",
                opencl = "opencl",
                objc = "c",
                objcpp = "cpp",
                vhdl = "vhdl"
            }

            local lang = lang_map[ft]
            if lang then
                return client, client.config.root_dir, lang
            end
        end
    end

    return nil, nil, nil
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

    -- second command :LspProfileReload - forces a regeneration of the config file
    vim.api.nvim_create_user_command("LspProfileReload", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local client, root_dir, lang = M.detect_active_lsp_for_buffer(bufnr)

        if not client then
            vim.notify("No LSP client attached to the current buffer", vim.log.levels.WARN)
            return
        end

        if not root_dir then
            vim.notify("No project root directory found", vim.log.levels.WARN)
            return
        end

        -- Clear the cache
        project_cache[root_dir] = nil

        -- Clear the buffer
        vim.b[bufnr].lsp_profile = nil

        -- Get profile and regenerate
        local profile = M.get_profile_for_buffer(bufnr, lang)
        local success = M.ensure_lsp_config(root_dir, lang, profile)

        if success then
            vim.notify(
                string.format("Reloaded profile: %s (%s)", profile, lang),
                vim.log.levels.INFO
            )
            -- Restart the LSP
            vim.cmd("LspRestart " .. client.name)
        else
            vim.notify("Failed to reload profile", vim.log.levels.ERROR)
        end
    end, {
        desc = "Force regenerate LSP config for current project"
        }
    )

    -- Command :LspProfileClean - remove an autogenerated config
    vim.api.nvim_create_user_command("LspProfileClean", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local client, root_dir, lang = M.detect_active_lsp_for_buffer(bufnr)

        if not client then
            vim.notify("No LSP client attached to current buffer", vim.log.levels.WARN)
            return
        end

        if not root_dir then
            vim.notify("No project root directory found", vim.log.levels.WARN)
            return
        end

        local config_filename = M.get_config_filename(lang)
        local config_path = root_dir .. "/" .. config_filename
        local is_ours, profile = M.is_our_config(config_path, lang)

        if not is_ours then
            vim.notify(config_filename .. " not generated by profile system", vim.log.levels.WARN)
            return
        end

        -- Remove it
        local success = pcall(function()
            os.remove(config_path)
        end)

        if success then
            project_cache[root_dir] = nil
            vim.notify("Removed generated " .. config_filename, vim.log.levels.INFO)
        else
            vim.notify("Failed to remove " .. config_filename, vim.log.levels.ERROR)
        end
    end, {
        desc = "Remove generated LSP config from current project"
        }
    )

    -- command : LspProfileInfo - LSP info but better
    vim.api.nvim_create_user_command("LspProfileInfo", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local client, root_dir, lang = M.detect_active_lsp_for_buffer(bufnr)

        if not client then
            vim.notify("No LSP client attached to current buffer", vim.log.levels.WARN)
            return
        end

        if not root_dir then
            vim.notify("No project root directory found", vim.log.levels.WARN)
            return
        end

        local profile = vim.b[bufnr].lsp_profile or "unknown"

        local config_filename = M.get_config_filename(lang)
        local config_path = root_dir .. "/" .. config_filename
        local config_status = "does not exist"
        local is_ours, existing_profile = M.is_our_config(config_path, lang)

        if vim.fn.filereadable(config_path) == 1 then
            if is_ours then
                config_status = string.format("generated (profile: %s)", existing_profile)
                local timestamp = vim.fn.getftime(config_path)
                local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
                config_status = config_status .. string.format("\n Last Modified: %s", date)
            else
                config_status = "user-managed (not made by the profile system)"
            end
        end

        local template_path = M.get_profile_path(lang, profile) .. "/" .. config_filename
        local template_exists = vim.fn.filereadable(template_path) == 1

        local info = {
            "LSP Profile Information:",
            "",
            " LSP Server: " .. client.name,
            " Language: " .. lang,
            " Profile: " .. profile,
            " Project Root: " .. root_dir,
            " Template Path: " .. template_path,
            " Template Exists: " .. (template_exists and "yes" or "no"),
            " " .. config_filename .. " status: " .. config_status,
        }

        vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
    end, {
        desc = "Show detailed LSP profile information"
        }
    )
end

return M
