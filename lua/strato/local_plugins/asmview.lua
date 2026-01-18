-- lua/strato/local_plugins/asmview.lua
return {
 -- "asmview",
  name = "asmview",
  dir = vim.fn.expand("~/.config/nvim/lua/strato/local_plugin_stubs/asmview"),
  event = "VeryLazy",
  config = function()

    -- State
    local enabled, asm_buf, asm_win, current_file = false, nil, nil, nil
    local autocmd_id, close_autocmd_id = nil, nil
    local view_mode = "spirv_text" -- spirv | spirv_text | sass | amd_isa
    local update_assembly

    -- Tools
    local function check_tool(tool) return vim.fn.executable(tool) == 1 end
    local function spirv_xlator()
      local h = io.popen("command -v llvm-spirv-20 || command -v llvm-spirv-18 || command -v llvm-spirv-15 || command -v llvm-spirv-14 || command -v llvm-spirv 2>/dev/null")
      local p = h and h:read("*l") or nil
      if h then h:close() end
      return p or "llvm-spirv-18"
    end
    local function which_any(list)
      for _, c in ipairs(list) do if vim.fn.executable(c) == 1 then return c end end
      return nil
    end
    local llc_cmd = which_any({"llc-20","llc-18","llc-17","llc"})

    -- Vendor/arch detect (best-effort)
    local function get_gpu_vendor_and_arch()
      local h = io.popen("nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits 2>/dev/null")
      if h then
        local r = h:read("*a"):gsub("%s+", ""); h:close()
        local major, minor = r:match("(%d+)%.(%d+)")
        if major and minor then
          local arch_num = tonumber(major) * 10 + tonumber(minor)
          -- CUDA toolkit dropped support for sm_50 and below
          if arch_num < 52 then
            return "nvidia_legacy", "sm_" .. major .. minor
          end
          return "nvidia", "sm_" .. major .. minor
        end
      end
      h = io.popen("rocminfo 2>/dev/null | grep 'Name:' | head -1")
      if h then
        local r = h:read("*a"); h:close()
        local arch = r:match("(gfx%d+)")
        if arch then return "amd", arch end
      end
      h = io.popen("clinfo 2>/dev/null | grep 'Device Name' | grep -i intel")
      if h then
        local r = h:read("*a"); h:close()
        if r:match("Intel") then
          if r:match("Arc") or r:match("DG2") then return "intel", "dg2" end
          if r:match("Xe") then return "intel", "tgl" end
        end
      end
      return "unknown", "generic"
    end

    -- Mode cycling
    local function get_display_mode()
      local vendor, _ = get_gpu_vendor_and_arch()
      if view_mode == "sass" and vendor == "nvidia_legacy" then
        return "SASS (PTX)"
      else
        return view_mode:upper()
      end
    end

    local function cycle_view_mode()
      local modes = {"spirv", "spirv_text", "sass", "amd_isa"}
      local idx = 1
      for i, m in ipairs(modes) do if m == view_mode then idx = i break end end
      view_mode = modes[(idx % #modes) + 1]
      if asm_buf and vim.api.nvim_buf_is_valid(asm_buf) then
        vim.api.nvim_buf_set_name(asm_buf, "Assembly [" .. get_display_mode() .. "]")
      end
      current_file = nil
      if enabled then vim.schedule(function() update_assembly() end) end
      vim.notify("Assembly view: " .. get_display_mode(), vim.log.levels.INFO)
    end

    -- Core compile pipeline
    local function compile_to_assembly(file_path)
      if not file_path or file_path == "" then return "-- No file to compile --" end
      if vim.fn.filereadable(file_path) == 0 then return "-- File not readable: " .. file_path .. " --" end

      local ext = file_path:match("%.([^%.]+)$") or ""
      local vendor, arch = get_gpu_vendor_and_arch()
      local cmd

      if ext == "c" then
        -- CPU assembly - always x86
        cmd = string.format("clang -S -O0 -masm=intel -o - '%s' 2>&1", file_path)

      elseif ext == "cl" then
        -- GPU assembly modes
        if view_mode == "spirv" then
          -- SPIR-V binary (hex dump)
          if check_tool("clang") then
            cmd = string.format(
              "clang -target spir64 -x cl -Xclang -finclude-default-header -cl-std=CL3.0 -O0 -emit-llvm -c '%s' -o - | %s -o - | xxd -c 32",
              file_path, spirv_xlator()
            )
          else
            return "-- clang not found --"
          end

        elseif view_mode == "spirv_text" then
          -- SPIR-V assembly (cross-platform GPU assembly)
          if check_tool("clang") and check_tool("spirv-dis") then
            cmd = string.format(
              "clang -target spir64 -x cl -Xclang -finclude-default-header -cl-std=CL3.0 -O0 -emit-llvm -c '%s' -o - | %s -o - | spirv-dis",
              file_path, spirv_xlator()
            )
          else
            return "-- spirv-dis not found (install SPIRV-Tools) --"
          end

        elseif view_mode == "sass" then
          -- NVIDIA native machine code
          if vendor == "nvidia" then
            if check_tool("clang") and llc_cmd and check_tool("ptxas") and check_tool("cuobjdump") then
              local tmp_ptx = "/tmp/asmview_temp.ptx"
              local tmp_cubin = "/tmp/asmview_temp.cubin"
              cmd = string.format(
                "clang -target nvptx64-nvidia-cuda -x cl -Xclang -finclude-default-header -cl-std=CL3.0 -O0 -emit-llvm -c '%s' -o -"
                .. " | %s -march=nvptx64 -mcpu=%s -O0 -o %s"
                .. " && ptxas -arch=%s %s -o %s"
                .. " && cuobjdump -sass %s",
                file_path, llc_cmd, arch, tmp_ptx, arch, tmp_ptx, tmp_cubin, tmp_cubin
              )
            else
              return "-- Need clang, llc, ptxas, cuobjdump for SASS --"
            end
          elseif vendor == "nvidia_legacy" then
            -- Use PTX for old GPUs (sm_50 and below)
            if check_tool("clang") then
              cmd = string.format(
                "clang -target nvptx64-nvidia-cuda -x cl -Xclang -finclude-default-header -cl-std=CL3.0 -S -O0 -o - '%s' 2>&1",
                file_path
              )
            else
              return "-- clang not found --"
            end
          else
            return "-- SASS requires NVIDIA GPU (detected: " .. vendor .. ") --"
          end

        elseif view_mode == "amd_isa" then
          -- AMD native assembly
          if vendor == "amd" then
            if check_tool("clang") then
              cmd = string.format(
                "clang -target amdgcn-amd-amdhsa -x cl -Xclang -finclude-default-header -cl-std=CL3.0 -mcpu=%s -S -O0 -o - '%s' 2>&1",
                arch, file_path
              )
            else
              return "-- AMD ROCm toolchain not found --"
            end
          else
            return "-- AMD ISA requires AMD GPU (detected: " .. vendor .. ") --"
          end
        end

      elseif ext == "spv" then
        -- Direct SPIR-V file disassembly
        if view_mode == "spirv_text" and check_tool("spirv-dis") then
          cmd = string.format("spirv-dis '%s' 2>&1", file_path)
        else
          cmd = string.format("xxd -c 32 '%s'", file_path)
        end

      else
        return "-- Unsupported file type: " .. ext .. " (supported: .c, .cl, .spv) --"
      end

      if not cmd then return "-- No command configured for this mode --" end

      local handle = io.popen(cmd)
      if not handle then return "-- Failed to execute compiler --" end
      local result = handle:read("*a")
      local ok = handle:close()
      if not ok or result == "" then
        return "-- Compilation failed or produced no output --\n" .. (result or "")
      end

      -- Clean output for readability
      if view_mode == "spirv_text" or view_mode == "sass" or view_mode == "amd_isa" then
        return result
      else
        -- Clean up hex dumps and CPU assembly
        local lines, cleaned = vim.split(result, "\n"), {}
        for _, line in ipairs(lines) do
          if not line:match("^%s*%.") and not line:match("^%s*#") and line:match("%S") then
            table.insert(cleaned, line)
          end
        end
        return table.concat(cleaned, "\n")
      end
    end

    -- Render/update
    update_assembly = function()
      if not enabled or not asm_buf or not vim.api.nvim_buf_is_valid(asm_buf) then return end
      local file_path = vim.api.nvim_buf_get_name(0)
      if file_path == current_file then return end
      current_file = file_path

      local ext = file_path:match("%.([^%.]+)$") or ""
      if ext ~= "c" and ext ~= "cl" and ext ~= "spv" then
        vim.api.nvim_buf_set_option(asm_buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(asm_buf, 0, -1, false, {
          "-- Not a supported file --",
          "File: " .. file_path,
          "Extension: " .. ext,
          "Supported: .c (CPU), .cl (GPU), .spv (SPIR-V)"
        })
        vim.api.nvim_buf_set_option(asm_buf, "modifiable", false)
        return
      end

      local assembly = compile_to_assembly(file_path)
      local lines = vim.split(assembly, "\n")
      vim.api.nvim_buf_set_option(asm_buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(asm_buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(asm_buf, "modifiable", false)

      -- Set appropriate syntax highlighting
      local syntax_map = {
        spirv = "yaml",
        spirv_text = "llvm",
        sass = "asm",
        amd_isa = "asm"
      }
      if ext == "c" then
        vim.api.nvim_buf_set_option(asm_buf, "filetype", "asm")
      else
        vim.api.nvim_buf_set_option(asm_buf, "filetype", syntax_map[view_mode] or "asm")
      end
    end

    -- Window management
    local function create_assembly_window()
      if asm_buf and vim.api.nvim_buf_is_valid(asm_buf) then return end
      local editor_win = vim.api.nvim_get_current_win()
      vim.cmd("FocusDisable")

      asm_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(asm_buf, "Assembly [" .. get_display_mode() .. "]")
      vim.api.nvim_buf_set_option(asm_buf, "buftype", "nofile")
      vim.api.nvim_buf_set_option(asm_buf, "swapfile", false)
      vim.api.nvim_buf_set_option(asm_buf, "modifiable", false)
      vim.api.nvim_buf_set_option(asm_buf, "filetype", "asm")
      vim.api.nvim_buf_set_option(asm_buf, "bufhidden", "wipe")

      vim.cmd("split")
      asm_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(asm_win, asm_buf)
      vim.api.nvim_win_set_option(asm_win, "wrap", true)
      vim.api.nvim_win_set_option(asm_win, "number", true)
      vim.api.nvim_win_set_option(asm_win, "linebreak", true)

      vim.api.nvim_set_current_win(editor_win)
      vim.cmd("FocusEnable")
      if asm_buf then vim.api.nvim_buf_set_var(asm_buf, "focus_disable", true) end

      vim.schedule(function() current_file = nil; update_assembly() end)
    end

    local function close_assembly_window()
      if asm_win and vim.api.nvim_win_is_valid(asm_win) then
        vim.api.nvim_win_close(asm_win, false); asm_win = nil
      end
      if asm_buf and vim.api.nvim_buf_is_valid(asm_buf) then
        vim.api.nvim_buf_delete(asm_buf, { force = true }); asm_buf = nil
      end
    end

    -- Toggle functionality
    local function enable_assembly_view()
      if enabled then return end
      enabled = true
      create_assembly_window()

      autocmd_id = vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter"}, {
        callback = function(args)
          local buf_name = vim.api.nvim_buf_get_name(args.buf)
          local ext = buf_name:match("%.([^%.]+)$") or ""
          if ext == "c" or ext == "cl" or ext == "spv" then
            if args.event == "BufWritePost" then current_file = nil end
            vim.schedule(update_assembly)
          end
        end,
        desc = "Update assembly view on file changes"
      })

      close_autocmd_id = vim.api.nvim_create_autocmd({"QuitPre", "BufDelete"}, {
        callback = function(args)
          if args.buf ~= asm_buf and enabled then
            enabled = false
            if autocmd_id then vim.api.nvim_del_autocmd(autocmd_id); autocmd_id = nil end
            close_assembly_window(); current_file = nil
            if close_autocmd_id then vim.api.nvim_del_autocmd(close_autocmd_id); close_autocmd_id = nil end
          end
        end,
        desc = "Close assembly view when main buffer closes"
      })

      vim.notify("Assembly view enabled", vim.log.levels.INFO)
    end

    local function disable_assembly_view()
      if not enabled then return end
      enabled = false
      if autocmd_id then vim.api.nvim_del_autocmd(autocmd_id); autocmd_id = nil end
      if close_autocmd_id then vim.api.nvim_del_autocmd(close_autocmd_id); close_autocmd_id = nil end
      close_assembly_window(); current_file = nil
      vim.notify("Assembly view disabled", vim.log.levels.INFO)
    end

    -- Public API
    local function toggle()
      if enabled then disable_assembly_view() else enable_assembly_view() end
    end

   local function cycle_mode()
      cycle_view_mode()
    end

    local function set_mode(mode)
      view_mode = mode
      if asm_buf and vim.api.nvim_buf_is_valid(asm_buf) then
        vim.api.nvim_buf_set_name(asm_buf, "Assembly [" .. get_display_mode() .. "]")
      end
      current_file = nil
      if enabled then update_assembly() end
      vim.notify("Assembly view: " .. get_display_mode(), vim.log.levels.INFO)
    end

    -- Commands
    vim.api.nvim_create_user_command("AsmViewToggle", toggle, {
      desc = "Toggle assembly view on/off"
    })

    vim.api.nvim_create_user_command("AsmViewMode", function(opts)
      if opts.args and opts.args ~= "" then
        set_mode(opts.args)
      else
        cycle_mode()
      end
    end, {
      nargs = "?",
      complete = function() return {"spirv", "spirv_text", "sass", "amd_isa"} end,
      desc = "Set or cycle assembly view mode"
    })

  end
}
