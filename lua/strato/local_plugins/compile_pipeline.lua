-- Build and run system with LSP profile integration
-- lua/strato/local_plugins/asmview.lua

return {
    "compile-pipeline",
    dir = vim.fn.expand("~/.config/nvim/lua/strato/local_plugin_stubs/compile_pipeline"),
    name = "compile-pipeline",
    event = "VeryLazy",
    config = function()
        local Pipeline = {}
        local profiles = require("strato.lsp.profiles")

        -- Track state
        local output_buffer = nil
        local output_window = nil
        local active_job = nil
        local saved_arguments = ""

        -- Parse .clangd file to extract compile flags
        local function parse_clangd_flags(clangd_path)
            if vim.fn.filereadable(clangd_path) == 0 then
                return nil
            end

            local file = io.open(clangd_path, "r")
            if not file then return nil end

            local content = file:read("*a")
            file:close()

            -- Extract CompileFlags section
            local compile_flags = content:match("CompileFlags:%s*\n(.-)\n%S")
            if not compile_flags then return nil end

            -- Extract Add section
            local add_section = compile_flags:match("Add:%s*%[(.-)%]")
            if not add_section then return nil end

            -- Parse flags into a table
            local flags = {}
            for flag in add_section:gmatch('"([^"]+)"') do
                table.insert(flags, flag)
            end

            return flags
        end

        -- Get compile flags for current project
        local function get_project_compile_flags(source_file)
            local bufnr = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({ bufnr = bufnr })

            local root_dir = nil
            for _, client in ipairs(clients) do
                if client.name == "clangd" and client.config.root_dir then
                    root_dir = client.config.root_dir
                    break
                end
            end

            if not root_dir then
                -- Fallback: search for .clangd in parent directories
                local dir = vim.fn.fnamemodify(source_file, ":h")
                for _ = 1, 10 do
                    local clangd_path = dir .. "/.clangd"
                    if vim.fn.filereadable(clangd_path) == 1 then
                        root_dir = dir
                        break
                    end
                    local parent = vim.fn.fnamemodify(dir, ":h")
                    if parent == dir then break end
                    dir = parent
                end
            end

            if root_dir then
                local clangd_path = root_dir .. "/.clangd"
                return parse_clangd_flags(clangd_path)
            end

            return nil
        end

        -- Language-specific build rules
        local languages = {
            c = {
                compile_command = function(source_file, binary_output)
                    local flags = get_project_compile_flags(source_file)

                    if flags then
                        -- Use project-specific flags from .clangd
                        local flags_str = table.concat(flags, " ")
                        return string.format("clang -o %s %s %s", binary_output, source_file, flags_str)
                    else
                        -- Fallback to defaults
                        return string.format("clang -o %s %s -O0 -std=c99 -Wall", binary_output, source_file)
                    end
                end,
                run_command = function(binary_output, user_args)
                    return string.format("%s %s", binary_output, user_args)
                end,
                requires_compilation = true,
            },

            cpp = {
                compile_command = function(source_file, binary_output)
                    local flags = get_project_compile_flags(source_file)

                    if flags then
                        -- Use project-specific flags from .clangd
                        local flags_str = table.concat(flags, " ")
                        return string.format("clang++ -o %s %s %s", binary_output, source_file, flags_str)
                    else
                        -- Fallback to defaults
                        return string.format("clang++ -o %s %s -O0 -std=c++17 -Wall", binary_output, source_file)
                    end
                end,
                run_command = function(binary_output, user_args)
                    return string.format("%s %s", binary_output, user_args)
                end,
                requires_compilation = true,
            },

            opencl = {
                compile_command = function(source_file, binary_output)
                    local flags = get_project_compile_flags(source_file)

                    if flags then
                        -- Use project-specific flags from .clangd
                        local flags_str = table.concat(flags, " ")
                        return string.format("clang -o %s %s %s", binary_output, source_file, flags_str)
                    else
                        -- Fallback to OpenCL defaults
                        return string.format("clang -o %s %s -xc -std=c99 -O0 -Dcl_clang_storage_class_specifiers", binary_output, source_file)
                    end
                end,
                run_command = function(binary_output, user_args)
                    return string.format("%s %s", binary_output, user_args)
                end,
                requires_compilation = true,
            },

            go = {
                run_command = function(source_file, user_args)
                    return string.format("go run %s %s", source_file, user_args)
                end,
                requires_compilation = false,
            },

            rust = {
                compile_command = function(source_file, binary_output)
                    return string.format("rustc -o %s %s", binary_output, source_file)
                end,
                run_command = function(binary_output, user_args)
                    return string.format("%s %s", binary_output, user_args)
                end,
                requires_compilation = true,
            },

            python = {
                run_command = function(source_file, user_args)
                    return string.format("python3 %s %s", source_file, user_args)
                end,
                requires_compilation = false,
            },

            zig = {
                compile_command = function(source_file, binary_output)
                    return string.format("zig build-exe %s -femit-bin=%s", source_file, binary_output)
                end,
                run_command = function(binary_output, user_args)
                    return string.format("%s %s", binary_output, user_args)
                end,
                requires_compilation = true,
            },
        }

        -- Create or show the output window
        local function show_output_window()
            if output_buffer and vim.api.nvim_buf_is_valid(output_buffer) then
                if not output_window or not vim.api.nvim_win_is_valid(output_window) then
                    vim.cmd("vsplit")
                    output_window = vim.api.nvim_get_current_win()
                    vim.api.nvim_win_set_buf(output_window, output_buffer)
                end
            else
                vim.cmd("vsplit")
                output_window = vim.api.nvim_get_current_win()
                output_buffer = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_name(output_buffer, "[Build Output]")
                vim.api.nvim_win_set_buf(output_window, output_buffer)
                vim.api.nvim_buf_set_option(output_buffer, "buftype", "nofile")
                vim.api.nvim_buf_set_option(output_buffer, "swapfile", false)
            end

            vim.cmd("wincmd p")
        end

        -- Append text to output buffer
        local function append_to_output(text_lines, clear_first)
            if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
                return
            end

            vim.schedule(function()
                vim.api.nvim_buf_set_option(output_buffer, "modifiable", true)

                if clear_first then
                    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})
                end

                local existing = vim.api.nvim_buf_get_lines(output_buffer, 0, -1, false)
                local combined = vim.list_extend(existing, text_lines)

                -- Prevent unbounded growth: keep only last 1000 lines
                local max_lines = 1000
                if #combined > max_lines then
                    combined = vim.list_slice(combined, #combined - max_lines + 1, #combined)
                end

                vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, combined)
                vim.api.nvim_buf_set_option(output_buffer, "modifiable", false)

                if output_window and vim.api.nvim_win_is_valid(output_window) then
                    vim.api.nvim_win_set_cursor(output_window, {#combined, 0})
                end
            end)
        end

        -- Show which profile is being used
        local function show_profile_info(source_file)
            local bufnr = vim.api.nvim_get_current_buf()
            local profile = vim.b[bufnr].lsp_profile

            if profile and profile ~= "standard" then
                local flags = get_project_compile_flags(source_file)
                if flags then
                    append_to_output({
                        "=== USING LSP PROFILE: " .. profile .. " ===",
                        "Flags: " .. table.concat(flags, " "),
                        ""
                    }, false)
                end
            end
        end

        -- Run compilation
        function Pipeline.compile_file()
            local source_file = vim.fn.expand("%:p")
            local file_extension = vim.fn.expand("%:e")
            local lang = languages[file_extension]

            if not lang then
                vim.notify("Unknown file type: ." .. file_extension, vim.log.levels.ERROR)
                return
            end

            if not lang.requires_compilation then
                vim.notify("This language doesn't need compilation", vim.log.levels.INFO)
                return
            end

            show_output_window()

            local binary_output = vim.fn.expand("%:p:r")
            local compile_cmd = lang.compile_command(source_file, binary_output)

            append_to_output({"=== COMPILING ===", "$ " .. compile_cmd, ""}, true)
            show_profile_info(source_file)

            if active_job then
                vim.fn.jobstop(active_job)
            end

            active_job = vim.fn.jobstart(compile_cmd, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data)
                    if data then append_to_output(data, false) end
                end,
                on_stderr = function(_, data)
                    if data then append_to_output(data, false) end
                end,
                on_exit = function(_, exit_code)
                    active_job = nil
                    if exit_code == 0 then
                        append_to_output({"", "=== BUILD SUCCESS ===", ""}, false)
                        vim.notify("Build successful", vim.log.levels.INFO)
                    else
                        append_to_output({"", "=== BUILD FAILED (code " .. exit_code .. ") ===", ""}, false)
                        vim.notify("Build failed", vim.log.levels.ERROR)
                    end
                end,
            })
        end

        -- Run program (compiles first if needed)
        function Pipeline.run_program(user_args)
            user_args = user_args or saved_arguments
            saved_arguments = user_args

            local source_file = vim.fn.expand("%:p")
            local file_extension = vim.fn.expand("%:e")
            local lang = languages[file_extension]

            if not lang then
                vim.notify("Unknown file type: ." .. file_extension, vim.log.levels.ERROR)
                return
            end

            show_output_window()

            local function execute_program()
                local run_cmd
                if lang.requires_compilation then
                    local binary_output = vim.fn.expand("%:p:r")
                    run_cmd = lang.run_command(binary_output, user_args)
                else
                    run_cmd = lang.run_command(source_file, user_args)
                end

                append_to_output({"", "=== RUNNING ===", "$ " .. run_cmd, ""}, false)

                vim.fn.jobstart(run_cmd, {
                    stdout_buffered = false,
                    stderr_buffered = false,
                    on_stdout = function(_, data)
                        if data then append_to_output(data, false) end
                    end,
                    on_stderr = function(_, data)
                        if data then append_to_output(data, false) end
                    end,
                    on_exit = function(_, exit_code)
                        append_to_output({"", "=== PROGRAM EXITED (code " .. exit_code .. ") ===", ""}, false)
                    end,
                })
            end

            if lang.requires_compilation then
                local binary_output = vim.fn.expand("%:p:r")
                local source_modified = vim.fn.getftime(source_file)
                local binary_modified = vim.fn.getftime(binary_output)

                if binary_modified < source_modified or binary_modified == -1 then
                    append_to_output({"=== COMPILING FIRST ===", ""}, true)
                    show_profile_info(source_file)

                    local compile_cmd = lang.compile_command(source_file, binary_output)
                    append_to_output({"$ " .. compile_cmd, ""}, false)

                    vim.fn.jobstart(compile_cmd, {
                        stdout_buffered = true,
                        stderr_buffered = true,
                        on_stdout = function(_, data)
                            if data then append_to_output(data, false) end
                        end,
                        on_stderr = function(_, data)
                            if data then append_to_output(data, false) end
                        end,
                        on_exit = function(_, exit_code)
                            if exit_code == 0 then
                                append_to_output({"", "=== BUILD SUCCESS ===", ""}, false)
                                execute_program()
                            else
                                append_to_output({"", "=== BUILD FAILED ===", ""}, false)
                                vim.notify("Build failed", vim.log.levels.ERROR)
                            end
                        end,
                    })
                else
                    execute_program()
                end
            else
                append_to_output({}, true)
                execute_program()
            end
        end

        -- Prompt for arguments then run
        function Pipeline.run_with_args()
            vim.ui.input({
                prompt = "Program arguments: ",
                default = saved_arguments,
            }, function(input)
                if input then
                    Pipeline.run_program(input)
                end
            end)
        end

        -- Close the output window
        function Pipeline.close_output()
            if output_window and vim.api.nvim_win_is_valid(output_window) then
                vim.api.nvim_win_close(output_window, true)
                output_window = nil
            end
        end

        -- Commands for use with keymaps
        vim.api.nvim_create_user_command("CompileFile", Pipeline.compile_file, { desc = "Compile current file" })
        vim.api.nvim_create_user_command("CompileRun", function() Pipeline.run_program("") end, { desc = "Compile and run" })
        vim.api.nvim_create_user_command("CompileRunArgs", Pipeline.run_with_args, { desc = "Run with arguments" })
        vim.api.nvim_create_user_command("CompileClose", Pipeline.close_output, { desc = "Close build output" })
    end
}
