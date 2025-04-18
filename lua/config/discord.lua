-- ~/.config/nvim/lua/config/discord.lua
local M = {}

function M.setup()
  local cord = require("cord")
  cord.setup({
    auto_update = true,
    debounce_timeout = 10,
    blacklist = {
      filetypes = { "NvimTree", "dashboard", "TelescopePrompt", "mason" },
      buftypes = { "terminal", "nofile", "quickfix", "prompt" },
    },
    editor = {
      client = "neovim",
      tooltip = "The Superior Text Editor",
    },
    advanced = {
      plugin = {
        cursor_update = "on_hold",
      },
      server = {
        update = "fetch",
      },
      hooks = {},
    },
  })
  return cord
end

function M.setup_appearance()
  return {
    display = {
      theme = "default",
      flavor = "dark",
    },
    idle = {
      icon = require("cord.api.icon").get("keyboard"),
    },
  }
end
function M.setup_text()
  return {
    editing = function(opts)
      if opts.filetype == "lua" then
        return "Scripting in Lua: " .. opts.filename
      elseif opts.filetype == "rust" then
        return "🦀 Crafting in Rust: " .. opts.filename
      else
        return "Editing " .. opts.filename
      end
    end,
    watching = "Viewing ${filename}",
    workspace = function(opts)
      local hour = tonumber(os.date("%H"))
      local status = hour >= 22 and "🌙 Late night coding"
        or hour >= 18 and "🌆 Evening session"
        or hour >= 12 and "☀️ Afternoon coding"
        or hour >= 5 and "🌅 Morning productivity"
        or "🌙 Midnight hacking"
      return string.format("%s: %s", status, opts.workspace or "Unknown project")
    end,
  }
end
function M.setup_assets()
  return {
    file_assets = function(opts)
      -- Check file extension first (if filename is available)
      if opts.filename then
        -- Check for .lua extension
        if opts.filename:match("%.lua$") then
          return {
            type = "language",
            icon = "lua",
            text = "Scripting in Lua",
          }
        elseif opts.filename:match("%.rs$") then
          return {
            type = "language",
            icon = "rust",
            text = "Writing Rust code",
          }
        end
      end

      if opts.filetype == "lua" then
        return {
          type = "language",
          icon = "lua",
          text = "Scripting in Lua",
        }
      elseif opts.filetype == "rust" then
        return {
          type = "language",
          icon = "rust",
          text = "Writing Rust code",
        }
      end

      -- Default fallback
      return {
        type = "language",
        text = "Editing " .. (opts.filetype or "file"),
      }
    end,
  }
end

function M.setup_buttons()
  return {
    buttons = function(opts)
      local buttons = {}

      if opts.repo_url then
        table.insert(buttons, {
          label = "View Repository",
          url = opts.repo_url,
        })
      end
      table.insert(buttons, {
        label = "Neovim Website",
        url = "https://neovim.io",
      })
      return buttons
    end,
  }
end

function M.setup_idle()
  return {
    idle = {
      state_text = "AFK",
      details_text = "Idle in Neovim",
      timeout = 300,
    },
    timestamp = {
      reset_on_idle = true,
    },
  }
end

function M.setup_hooks()
  return {
    on_idle = function(activity)
      activity.details = "Away from keyboard"
    end,
  }
end

function M.setup_advanced()
  return {
    advanced = {
      plugin = {
        cursor_update = "on_hold", -- Options: "on_move", "on_hold", "none"
      },
      -- Server configuration
      server = {
        update = "fetch",
      },
      discord = {
        reconnect = {
          enabled = true,
          interval = 5000,
          initial = true,
        },
      },
    },
  }
end
-- Configure keymappings for cord control
function M.setup_keymaps()
  vim.keymap.set("n", "<leader>dt", function()
    require("cord.api.command").toggle_presence()
  end, { desc = "Toggle Discord presence" })

  vim.keymap.set("n", "<leader>di", function()
    require("cord.api.command").toggle_idle_force()
  end, { desc = "Toggle forced idle status" })

  vim.keymap.set("n", "<leader>dr", function()
    require("cord.api.command").reconnect()
  end, { desc = "Reconnect Discord presence" })
end
function M.setup_all()
  M.setup()
  M.setup_appearance()
  M.setup_text()
  M.setup_assets()
  M.setup_buttons()
  M.setup_idle()
  M.setup_hooks()
  M.setup_keymaps()
end
return M
