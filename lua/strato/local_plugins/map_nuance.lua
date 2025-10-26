-- lua/strato/lazy/map_nuance.lua
return {
  "map-nuance",
  name = "map-nuance",
  dir = vim.fn.expand("~/.config/nvim/lua/strato/local_plugin_stubs/map_nuance"),
  lazy = false,
  config = function()
    local dev_keys_active = false

    local function activate_dev_keys()
      -- Run asynchronously get that speed
      vim.fn.jobstart("setxkbmap -option ctrl:nocaps", {
        on_exit = function(_, exit_code)
          if exit_code == 0 then
            vim.fn.jobstart("xcape -e 'Control_L=Escape' -t 150", {
              on_exit = function(_, code)
                if code == 0 then
                  dev_keys_active = true
                  vim.schedule(function()
                    vim.notify("Dev keyboard layout activated", vim.log.levels.INFO)
                  end)
                else
                  vim.schedule(function()
                    vim.notify("Failed to start xcape", vim.log.levels.ERROR)
                  end)
                end
              end
            })
          else
            vim.schedule(function()
              vim.notify("Failed to activate dev keys", vim.log.levels.ERROR)
            end)
          end
        end
      })
    end

    local function deactivate_dev_keys()
      vim.fn.jobstart("pkill xcape", {
        on_exit = function()
          vim.fn.jobstart("setxkbmap -option", {
            on_exit = function()
              dev_keys_active = false
              vim.schedule(function()
                vim.notify("Normal keyboard layout restored", vim.log.levels.INFO)
              end)
            end
          })
        end
      })
    end

    local function toggle_dev_keys()
      if dev_keys_active then
        deactivate_dev_keys()
      else
        activate_dev_keys()
      end
    end

    -- Activate asynchronously after UI loads
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.schedule(function()
          activate_dev_keys()
        end)
      end,
      once = true,
    })

    vim.api.nvim_create_user_command("ToggleDevKeys", toggle_dev_keys, {
      desc = "Toggle dev keyboard layout"
    })

    vim.api.nvim_create_autocmd({"VimLeave", "VimLeavePre"}, {
      callback = deactivate_dev_keys,
    })
  end,
}
