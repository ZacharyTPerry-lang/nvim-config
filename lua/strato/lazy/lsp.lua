return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        require("conform").setup({
            formatters_by_ft = {}
        })

        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities()
        )

        require("fidget").setup({})
        require("mason").setup()

        local profiles = require("strato.lsp.profiles")

        --
        -- LUA (NVIM)
        --

        -- Configure lua_ls to recognize vim global
        vim.lsp.config('lua_ls', {
            cmd = { 'lua-language-server' },
            filetypes = { 'lua' },
            root_markers = { '.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', '.git' },
            capabilities = capabilities,
            settings = {
                Lua = {
                    runtime = { version = 'LuaJIT' },
                    diagnostics = { globals = { 'vim' } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                    telemetry = { enable = false },
                    format = {
                        enable = true,
                        defaultConfig = {
                            indent_style = "space",
                            indent_size = "2",
                        }
                    },
                }
            }
        })

        --
        -- C and C++
        --

        -- Configure clangd for C/C++/OpenCL
        vim.lsp.config('clangd', {
            cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--completion-style=detailed",
                "--header-insertion=iwyu",
            },
            filetypes = { "c", "cpp", "objc", "objcpp", "opencl" },
            root_markers = {'.lsp-profile', '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', '.git' },
            capabilities = capabilities,
            on_attach = function(client, bufnr)
                local root_dir = client.config.root_dir
                if not root_dir then return end

                if not profiles.is_safe_project_root(root_dir) then
                    return
                end

                local detected_ft = profiles.detect_header_language(root_dir, bufnr)
                local lang_map = {
                    c = "c",
                    cpp = "cpp",
                    opencl = "opencl",
                    objc = "c",
                    objcpp = "cpp"
                }
                local lang = lang_map[detected_ft] or "c"

                local cached = profiles.get_or_create_project_cache(root_dir)

                if cached.checked then
                    vim.b[bufnr].lsp_profile = cached.profile
                    return
                end

                local profile = profiles.get_profile_for_buffer(bufnr, lang)
                local success = profiles.ensure_lsp_config(root_dir, lang, profile)

                if success then
                    cached.profile = profile
                    cached.checked = true
                    vim.b[bufnr].lsp_profile = profile

                    if profile ~= "standard" then
                        vim.schedule(function()
                            vim.notify(
                                string.format("LSP Profile: %s (%s)", profile, lang),
                                vim.log.levels.INFO
                            )
                        end)
                    end
                else
                    cached.profile = profile
                    cached.checked = true
                    vim.b[bufnr].lsp_profile = profile
                end

                local profile_file = profiles.find_lsp_profile_file(root_dir)
                if not profile_file then
                    profiles.cleanup_orphaned_config(root_dir, lang)
                end
            end,
            init_options = {
                clangdFileStatus = true,
                usePlaceholders = true,
                completeUnimported = true,
                semanticHighlighting = true,
            },
            on_new_config = function(config, root_dir)
                local ft = vim.bo.filetype

                if ft == "c" then
                    config.init_options.fallbackFlags = {
                        "-std=c99",
                        "-O0",
                        "-Wall",
                    }
                elseif ft == "opencl" then
                    config.init_options.fallbackFlags = {
                        "-xc",
                        "-std=c99",
                        "-O0",
                        "-Dcl_clang_storage_class_specifiers",
                    }
                else
                    config.init_options.fallbackFlags = {
                        "-std=c++17",
                        "-Wall",
                        "-Wextra",
                    }
                end
            end,
        })

        --
        -- VHDL
        --

        -- Configure ghdl_ls for VHDL
        vim.lsp.config('ghdl_ls', {
            cmd = { 'ghdl-ls' },
            filetypes = { 'vhdl' },
            root_markers = { '.lsp-profile', '.ghdl-ls.json', '.git' },
            capabilities = capabilities,
            on_attach = function(client, bufnr)
                local root_dir = client.config.root_dir
                if not root_dir then return end

                if not profiles.is_safe_project_root(root_dir) then
                    return
                end

                local lang = "vhdl"  -- VHDL files are always VHDL

                local cached = profiles.get_or_create_project_cache(root_dir)

                if cached.checked then
                    vim.b[bufnr].lsp_profile = cached.profile
                    return
                end

                local profile = profiles.get_profile_for_buffer(bufnr, lang)
                local success = profiles.ensure_lsp_config(root_dir, lang, profile)

                if success then
                    cached.profile = profile
                    cached.checked = true
                    vim.b[bufnr].lsp_profile = profile

                    if profile ~= "standard" then
                        vim.schedule(function()
                            vim.notify(
                                string.format("LSP Profile: %s (vhdl)", profile),
                                vim.log.levels.INFO
                            )
                        end)
                    end
                else
                    cached.profile = profile
                    cached.checked = true
                    vim.b[bufnr].lsp_profile = profile
                end

                local profile_file = profiles.find_lsp_profile_file(root_dir)
                if not profile_file then
                    profiles.cleanup_orphaned_config(root_dir, lang)
                end
            end,
        })

        -- Configure zls
        vim.lsp.config('zls', {
            cmd = { 'zls' },
            filetypes = { 'zig', 'zir' },
            root_markers = { 'zls.json', 'build.zig', '.git' },
            capabilities = capabilities,
            settings = {
                zls = {
                    enable_inlay_hints = true,
                    enable_snippets = true,
                    warn_style = true,
                },
            },
        })
        vim.g.zig_fmt_parse_errors = 0
        vim.g.zig_fmt_autosave = 0

        -- Configure other LSPs with defaults
        vim.lsp.config('gopls', {
            cmd = { 'gopls' },
            filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
            capabilities = capabilities,
        })

        vim.lsp.config('rust_analyzer', {
            cmd = { 'rust-analyzer' },
            filetypes = { 'rust' },
            capabilities = capabilities,
        })

        vim.lsp.config('pyright', {
            cmd = { 'pyright-langserver', '--stdio' },
            filetypes = { 'python' },
            capabilities = capabilities,
        })

        -- Enable LSPs
        vim.lsp.enable('lua_ls')
        vim.lsp.enable('clangd')
        vim.lsp.enable('ghdl_ls')  -- Enable VHDL LSP
        vim.lsp.enable('zls')
        vim.lsp.enable('gopls')
        vim.lsp.enable('rust_analyzer')
        vim.lsp.enable('pyright')

        -- Completion setup
        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            mapping = {
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-t>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            },
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
            }, {
                { name = 'buffer' },
            })
        })

        -- Diagnostic configuration
        vim.diagnostic.config({
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })
    end
}
