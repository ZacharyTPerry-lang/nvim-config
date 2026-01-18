-- lua/strato/local_plugins/map_nuance.lua
-- Multi-instance safe keyboard layout manager with debug logging
return {
  "map-nuance",
  name = "map-nuance",
  dir = vim.fn.expand("~/.config/nvim/lua/strato/local_plugin_stubs/map_nuance"),
  lazy = false,
  config = function()
    local LOCKFILE = "/tmp/nvim-devkeys.lock"
    local LOGFILE = "/tmp/nvim-devkeys.log"
    local deactivation_done = false

    -- Debug logger - defined FIRST so everything can use it
    local function log(msg)
      local file = io.open(LOGFILE, "a")
      if file then
        local timestamp = os.date("%H:%M:%S")
        local pid = vim.loop.os_getpid()
        file:write(string.format("[%s][PID:%d] %s\n", timestamp, pid, msg))
        file:close()
      end
    end

    log("Plugin config starting")

    -- Process verification
    local function is_xcape_running()
      local handle = io.popen("pgrep -x xcape 2>/dev/null")
      if not handle then return false end
      local result = handle:read("*a")
      handle:close()
      return result and result:match("%d+") ~= nil
    end

    -- Keyboard mapping verification - check if Caps is actually mapped to Ctrl
    local function is_keyboard_configured()
      local handle = io.popen("setxkbmap -query | grep 'options.*ctrl:nocaps' 2>/dev/null")
      if not handle then return false end
      local result = handle:read("*a")
      handle:close()
      -- If the output contains ctrl:nocaps, keyboard is configured
      return result and result:match("ctrl:nocaps") ~= nil
    end

    -- Combined health check - both process AND keyboard config must be correct
    local function is_devkeys_healthy()
      return is_xcape_running() and is_keyboard_configured()
    end

    -- Critical section lock using mkdir (atomic operation)
    local function with_lock(callback)
      local lockdir = LOCKFILE .. ".lock"
      local max_attempts = 100
      local attempt = 0

      -- Try to create lock directory (atomic operation)
      while attempt < max_attempts do
        local success = vim.loop.fs_mkdir(lockdir, 493)
        if success then
          break
        end

        vim.loop.sleep(20)
        attempt = attempt + 1

        -- Check for stale locks
        if attempt % 10 == 0 then
          local stat = vim.loop.fs_stat(lockdir)
          if stat then
            local age = os.time() - stat.mtime.sec
            if age > 5 then
              log("Removing stale lock (age: " .. age .. "s)")
              vim.loop.fs_rmdir(lockdir)
            end
          end
        end
      end

      if attempt >= max_attempts then
        log("FAILED to acquire lock after " .. max_attempts .. " attempts")
        return nil
      end

      local ok, result = pcall(callback)
      vim.loop.fs_rmdir(lockdir)

      if not ok then
        log("ERROR in locked section: " .. tostring(result))
      end

      return result
    end

    -- Lockfile operations
    local function read_lockfile()
      local file = io.open(LOCKFILE, "r")
      if not file then return nil end
      local content = file:read("*a")
      file:close()
      if not content or content == "" then return nil end
      local ok, data = pcall(vim.json.decode, content)
      return ok and data or nil
    end

    local function write_lockfile(data)
      local content = vim.json.encode(data)
      local temp_file = LOCKFILE .. ".tmp." .. vim.loop.os_getpid()
      local file = io.open(temp_file, "w")
      if not file then
        log("FAILED to open temp file for writing")
        return false
      end
      file:write(content)
      file:close()
      local ok = os.rename(temp_file, LOCKFILE)
      if not ok then
        os.remove(temp_file)
        log("FAILED to rename temp file to lockfile")
        return false
      end
      return true
    end

    local function delete_lockfile()
      log("Deleting lockfile")
      os.remove(LOCKFILE)
    end

    -- Forward declare to avoid circular dependency
    local spawn_keyboard_setup

    -- Keyboard setup
    spawn_keyboard_setup = function(on_complete)
      log("Spawning keyboard setup")
      vim.fn.jobstart("setxkbmap -option ctrl:nocaps", {
        on_exit = function(_, exit_code)
          if exit_code ~= 0 then
            log("setxkbmap FAILED with code " .. exit_code)
            vim.schedule(function()
              on_complete(false)
            end)
            return
          end
          vim.fn.jobstart("xcape -e 'Control_L=Escape' -t 150", {
            on_exit = function(_, code)
              vim.schedule(function()
                if code == 0 then
                  log("xcape started successfully")
                  vim.notify("Dev keyboard layout activated", vim.log.levels.INFO)
                  on_complete(true)
                else
                  log("xcape FAILED with code " .. code)
                  on_complete(false)
                end
              end)
            end
          })
        end
      })
    end

    local function teardown_keyboard_setup(on_complete)
      log("Tearing down keyboard setup")
      vim.fn.jobstart("pkill -x xcape", {
        on_exit = function()
          vim.fn.jobstart("setxkbmap -option", {
            on_exit = function()
              vim.schedule(function()
                log("Keyboard teardown complete")
                vim.notify("Normal keyboard layout restored", vim.log.levels.INFO)
                if on_complete then
                  on_complete()
                end
              end)
            end
          })
        end
      })
    end

    -- Main activation
    local function activate_dev_keys()
      log("activate_dev_keys() called")
      with_lock(function()
        local lockdata = read_lockfile()
        local xcape_alive = is_xcape_running()
        local my_pid = vim.loop.os_getpid()

        if not lockdata and not xcape_alive then
          log("First instance - spawning")
          spawn_keyboard_setup(function(success)
            if success then
              with_lock(function()
                write_lockfile({
                  count = 1,
                  activated_at = os.time(),
                  pids = {my_pid}
                })
                log("Lockfile created with count=1")
              end)
            end
          end)
        elseif not lockdata and xcape_alive then
          -- FIX: Don't just adopt - orphaned xcape might be running but keyboard not configured!
          log("Found orphaned xcape - re-running full setup to ensure keyboard config")
          vim.fn.jobstart("pkill -x xcape", {
            on_exit = function()
              log("Orphaned xcape killed, starting fresh")
              spawn_keyboard_setup(function(success)
                if success then
                  with_lock(function()
                    write_lockfile({
                      count = 1,
                      activated_at = os.time(),
                      pids = {my_pid}
                    })
                    log("Lockfile created after orphan cleanup")
                  end)
                end
              end)
            end
          })
        else
          log("Additional instance, incrementing count")
          lockdata.count = lockdata.count + 1

          -- Migrate old format
          if lockdata.pid and not lockdata.pids then
            lockdata.pids = {lockdata.pid}
            lockdata.pid = nil
          end
          lockdata.pids = lockdata.pids or {}

          -- Add PID if not already tracked
          local already_tracked = false
          for _, pid in ipairs(lockdata.pids) do
            if pid == my_pid then
              already_tracked = true
              break
            end
          end
          if not already_tracked then
            table.insert(lockdata.pids, my_pid)
          end

          write_lockfile(lockdata)
          log(string.format("Count incremented to %d, PIDs: %s",
            lockdata.count, table.concat(lockdata.pids, ",")))
        end
      end)
    end

    -- Main deactivation
    local function deactivate_dev_keys()
      log("=== deactivate_dev_keys() CALLED ===")

      if deactivation_done then
        log("Guard: Already deactivated, returning")
        return
      end
      log("Guard: Setting deactivation_done = true")
      deactivation_done = true

      with_lock(function()
        log("Lock acquired")
        local lockdata = read_lockfile()
        local my_pid = vim.loop.os_getpid()

        if not lockdata then
          log("ERROR: No lockfile found!")
          if is_xcape_running() then
            log("Cleaning up unmanaged xcape")
            teardown_keyboard_setup(function() end)
          end
          return
        end

        log(string.format("Lockfile read: count=%d, pids=%s",
          lockdata.count,
          table.concat(lockdata.pids or {}, ",")))

        -- Remove this PID
        if lockdata.pids then
          local new_pids = {}
          for _, pid in ipairs(lockdata.pids) do
            if pid ~= my_pid then
              table.insert(new_pids, pid)
            end
          end
          lockdata.pids = new_pids
          log("After PID removal: " .. table.concat(new_pids, ","))
        end

        local old_count = lockdata.count
        lockdata.count = lockdata.count - 1
        log(string.format("Count: %d -> %d", old_count, lockdata.count))

        -- FIX: Delete lockfile AFTER teardown completes, not before
        if lockdata.count <= 0 then
          log("Count <= 0: Tearing down then deleting lockfile")
          if is_xcape_running() then
            teardown_keyboard_setup(function()
              -- Delete lockfile AFTER xcape is actually killed
              delete_lockfile()
            end)
          else
            delete_lockfile()
          end
        else
          log(string.format("Count > 0: Writing lockfile with count=%d", lockdata.count))
          local success = write_lockfile(lockdata)
          log("write_lockfile returned: " .. tostring(success))
          vim.notify("Detached from shared keyboard layout (count: " .. lockdata.count .. ")", vim.log.levels.INFO)
        end
      end)
      log("=== deactivate_dev_keys() DONE ===")
    end

    -- Toggle and health check
    local function toggle_dev_keys()
      log("toggle_dev_keys() called")
      local lockdata = read_lockfile()
      local should_be_active = lockdata ~= nil and lockdata.count > 0

      if should_be_active then
        if lockdata then
          lockdata.count = 0
          write_lockfile(lockdata)
        end
        teardown_keyboard_setup(function()
          delete_lockfile()
        end)
      else
        delete_lockfile()
        spawn_keyboard_setup(function(success)
          if success then
            write_lockfile({
              count = 1,
              activated_at = os.time(),
              pids = {vim.loop.os_getpid()}
            })
          end
        end)
      end
    end

    local function health_check()
      local lockdata = read_lockfile()
      local xcape_alive = is_xcape_running()
      local kb_configured = is_keyboard_configured()
      local my_pid = vim.loop.os_getpid()

      local pids_str = "N/A"
      local am_i_tracked = false

      if lockdata then
        if lockdata.pid and not lockdata.pids then
          pids_str = tostring(lockdata.pid) .. " (old format)"
          am_i_tracked = (lockdata.pid == my_pid)
        elseif lockdata.pids then
          pids_str = table.concat(lockdata.pids, ", ")
          for _, pid in ipairs(lockdata.pids) do
            if pid == my_pid then
              am_i_tracked = true
              break
            end
          end
        end
      end

      local expected_active = lockdata and lockdata.count > 0
      local actually_healthy = xcape_alive and kb_configured
      local state_str
      if expected_active and actually_healthy then
        state_str = "✓ synced"
      elseif expected_active and not actually_healthy then
        state_str = "✗ UNHEALTHY (xcape:" .. tostring(xcape_alive) .. " kb:" .. tostring(kb_configured) .. ")"
      elseif not expected_active and not actually_healthy then
        state_str = "✓ synced (disabled)"
      else
        state_str = "✗ desynced"
      end

      local msg = string.format(
        "DevKeys Health:\n" ..
        "  Lockfile: %s\n" ..
        "  Instance count: %s\n" ..
        "  Tracked PIDs: %s\n" ..
        "  This PID: %s %s\n" ..
        "  xcape running: %s\n" ..
        "  Keyboard configured: %s\n" ..
        "  State: %s",
        lockdata and "exists" or "missing",
        lockdata and lockdata.count or "N/A",
        pids_str,
        my_pid,
        am_i_tracked and "(✓ tracked)" or "(✗ NOT TRACKED)",
        xcape_alive and "yes" or "no",
        kb_configured and "yes" or "no",
        state_str
      )

      print(msg)
    end

    -- Autocmds
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        log("VimEnter event fired")
        vim.schedule(function()
          activate_dev_keys()
        end)
      end,
      once = true,
    })

    vim.api.nvim_create_autocmd({"VimLeave", "VimLeavePre"}, {
      callback = function(ev)
        log(string.format("%s event fired", ev.event))
        deactivate_dev_keys()
      end,
    })

    -- Watchdog: Auto-respawn xcape if it dies (e.g., after suspend/resume)
    vim.api.nvim_create_autocmd("FocusGained", {
      callback = function()
        log("FocusGained event fired")
        local lockdata = read_lockfile()
        if lockdata and lockdata.count > 0 then
          if not is_devkeys_healthy() then
            local xcape_alive = is_xcape_running()
            local kb_configured = is_keyboard_configured()
            log(string.format("WATCHDOG: Unhealthy state detected (xcape:%s, kb:%s), respawning!",
              xcape_alive, kb_configured))
            vim.notify("Keyboard layout unhealthy (suspend/X11 reset?), reactivating...", vim.log.levels.WARN)

            -- Kill any stale xcape first
            if xcape_alive then
              vim.fn.jobstart("pkill -x xcape", {
                on_exit = function()
                  spawn_keyboard_setup(function(success)
                    if success then
                      log("WATCHDOG: Full keyboard setup respawned successfully")
                    else
                      log("WATCHDOG: Respawn FAILED")
                    end
                  end)
                end
              })
            else
              spawn_keyboard_setup(function(success)
                if success then
                  log("WATCHDOG: Full keyboard setup respawned successfully")
                else
                  log("WATCHDOG: Respawn FAILED")
                end
              end)
            end
          else
            log("FocusGained: keyboard healthy, no action needed")
          end
        end
      end,
    })

    -- Additional watchdog: Check on cursor movement (catches suspend/resume without focus change)
    -- Throttle to avoid checking too frequently
    local last_check_time = 0
    local check_interval = 10 -- seconds

    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "InsertEnter"}, {
      callback = function()
        local now = os.time()
        if now - last_check_time < check_interval then
          return -- Too soon, skip check
        end
        last_check_time = now

        log("User activity detected, checking keyboard health")
        local lockdata = read_lockfile()
        if lockdata and lockdata.count > 0 then
          if not is_devkeys_healthy() then
            local xcape_alive = is_xcape_running()
            local kb_configured = is_keyboard_configured()
            log(string.format("WATCHDOG: Unhealthy state detected (xcape:%s, kb:%s), respawning!",
              xcape_alive, kb_configured))
            vim.notify("Keyboard layout unhealthy (suspend/X11 reset?), reactivating...", vim.log.levels.WARN)

            -- Kill any stale xcape first
            if xcape_alive then
              vim.fn.jobstart("pkill -x xcape", {
                on_exit = function()
                  spawn_keyboard_setup(function(success)
                    if success then
                      log("WATCHDOG: Full keyboard setup respawned successfully")
                    else
                      log("WATCHDOG: Respawn FAILED")
                    end
                  end)
                end
              })
            else
              spawn_keyboard_setup(function(success)
                if success then
                  log("WATCHDOG: Full keyboard setup respawned successfully")
                else
                  log("WATCHDOG: Respawn FAILED")
                end
              end)
            end
          end
        end
      end,
    })

    -- Commands
    vim.api.nvim_create_user_command("ToggleDevKeys", toggle_dev_keys, {
      desc = "Toggle dev keyboard layout"
    })

    vim.api.nvim_create_user_command("DevKeysHealth", health_check, {
      desc = "Check dev keyboard state"
    })

    vim.api.nvim_create_user_command("DevKeysLog", function()
      vim.cmd("vsplit " .. LOGFILE)
    end, {
      desc = "View debug log"
    })

    vim.api.nvim_create_user_command("DevKeysClearLog", function()
      local file = io.open(LOGFILE, "w")
      if file then file:close() end
      print("Log cleared")
    end, {
      desc = "Clear debug log"
    })

    log("Plugin config complete")
  end,
}
