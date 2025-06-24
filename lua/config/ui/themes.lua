-- ~/.config/nvim/lua/config/ui/themes.lua
local M = {}
M.current_theme = "nightfox"
M.themes = {
  catppuccin = {
    setup = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
        term_colors = true,
        integrations = {
          nvimtree = true,
          gitsigns = true,
          indent_blankline = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme("catppuccin")
    end,
    discord_name = "Catppuccin",
    discord_icon = "🍧",
  },
  tokyonight = {
    setup = function()
      require("tokyonight").setup({
        style = "night",
        transparent = true,
      })
    end,
    apply = function()
      vim.cmd.colorscheme("tokyonight")
    end,
    discord_name = "Tokyo Night",
    discord_icon = "🗼",
  },
  onedark = {
    setup = function()
      require("onedark").setup({
        style = "deep",
        transparent = true,
      })
    end,
    apply = function()
      vim.cmd.colorscheme("onedark")
    end,
    discord_name = "One Dark",
    discord_icon = "🌑",
  },
  gruvbox = {
    setup = function()
      vim.g.gruvbox_material_background = "medium"
      vim.g.gruvbox_material_enable_bold = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_transparent_background = 1
    end,
    apply = function()
      vim.cmd.colorscheme("gruvbox-material")
    end,
    discord_name = "Gruvbox Material",
    discord_icon = "🧸",
  },
  nightfox = {
    setup = function()
      require("nightfox").setup({
        options = {
          transparent = true,
          styles = {
            comments = "italic",
            keywords = "bold",
          },
        },
        integrations = {
          indent_blankline = {
            enabled = true,
            colored_indent_levels = true,
          },
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme("nightfox")
    end,
    discord_name = "Nightfox",
    discord_icon = "🦊",
  },
  nord = {
    setup = function()
      vim.g.nord_transparent = true
    end,
    apply = function()
      vim.cmd.colorscheme("nord")
    end,
    discord_name = "Nord",
    discord_icon = "❄️",
  },
  material = {
    setup = function()
      require("material").setup({
        contrast = {
          sidebars = true,
          floating_windows = true,
        },
        styles = {
          comments = { italic = true },
          keywords = { bold = true },
        },
        disable = {
          background = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme("material")
    end,
    discord_name = "Material",
    discord_icon = "🎨",
  },
  dracula = {
    setup = function()
      require("dracula").setup({
        transparent_bg = true,
      })
    end,
    apply = function()
      vim.cmd.colorscheme("dracula")
    end,
    discord_name = "Dracula",
    discord_icon = "🧛",
  },
  github = {
    setup = function()
      require("github-theme").setup({
        options = {
          transparent = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme("github_dark")
    end,
    discord_name = "GitHub Dark",
    discord_icon = "🐙",
  },
  onedarkpro = {
    setup = function()
      require("onedarkpro").setup({
        dark_theme = "onedark_vivid",
        options = {
          transparency = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme("onedark_vivid")
    end,
    discord_name = "OneDark Pro",
    discord_icon = "⚫",
  },
}
function M.set_theme(theme_name)
  local theme = M.themes[theme_name]
  if not theme then
    vim.notify("Theme not found: " .. theme_name, vim.log.levels.ERROR)
    return false
  end
  local ok_setup, err_setup = pcall(theme.setup)
  if not ok_setup then
    vim.notify("Failed to set up theme " .. theme_name .. ": " .. err_setup, vim.log.levels.ERROR)
    return false
  end
  local ok_apply, err_apply = pcall(theme.apply)
  if not ok_apply then
    vim.notify("Failed to apply theme: " .. err_apply, vim.log.levels.ERROR)
    return false
  end
  M.current_theme = theme_name
  if M.discord_initialized then
    M.update_cord_theme()
  end
  return true
end
function M.apply_current_theme()
  return M.set_theme(M.current_theme)
end
function M.update_cord_theme()
  local theme = M.themes[M.current_theme]
  if not theme or not M.cord_initialized or not M.cord then
    return
  end
  M.cord:update_presence({
    custom_details = "Using " .. theme.discord_name .. " theme " .. theme.discord_icon,
  })
end
function M.setup_appearance()
  return {
    theme = M.current_theme,
    icon = M.themes[M.current_theme].discord_icon or "🎨",
    text = "Using " .. M.themes[M.current_theme].discord_name,
  }
end
function M.setup_commands()
  vim.api.nvim_create_user_command("Theme", function(opts)
    local theme_name = opts.args
    if theme_name == "" then
      local themes = {}
      for name, _ in pairs(M.themes) do
        table.insert(themes, name)
      end
      vim.notify("Available themes: " .. table.concat(themes, ", "), vim.log.levels.INFO)
      return
    end
    M.set_theme(theme_name)
  end, {
    nargs = "?",
    complete = function()
      local themes = {}
      for name, _ in pairs(M.themes) do
        table.insert(themes, name)
      end
      return themes
    end,
  })
end
function M.setup_cord()
  local cord_mod = require("cord")
  local instance = cord_mod.setup({
    editor = { client = "neovim", tooltip = "The Superior Text Editor" },
    advanced = { plugin = { cursor_update = "on_hold" } },
    server = { update = "fetch" },
    appearance = M.setup_appearance(),
    text = M.setup_text(),
    assets = M.setup_assets(),
    buttons = M.setup_buttons(),
    idle = M.setup_idle().idle,
    timestamp = M.setup_idle().timestamp,
    hooks = M.setup_hooks().hooks,
  })
  return instance
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
function M.setup_assets()
  return {
    file_assets = function(opts)
      if opts.filename then
        if opts.filename:match("%.lua$") then
          return { type = "language", icon = "lua", text = "Scripting in Lua" }
        elseif opts.filename:match("%.rs$") then
          return { type = "language", icon = "rust", text = "Writing Rust code" }
        end
      end
      if opts.filetype == "lua" then
        return { type = "language", icon = "lua", text = "Scripting in Lua" }
      elseif opts.filetype == "rust" then
        return { type = "language", icon = "rust", text = "Writing Rust code" }
      end
      return { type = "language", text = "Editing " .. (opts.filetype or "file") }
    end,
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
function M.setup_buttons()
  return {
    buttons = function(opts)
      local buttons = {}
      if opts.repo_url then
        table.insert(buttons, { label = "View Repository", url = opts.repo_url })
      end
      table.insert(buttons, { label = "Neovim Website", url = "https://neovim.io" })
      return buttons
    end,
  }
end
function M.setup_hooks()
  return {
    hooks = {
      on_idle = function(activity)
        activity.details = "Away from keyboard"
      end,
    },
  }
end
function M.setup_all()
  M.apply_current_theme()
  local ok, cord = pcall(M.setup_cord)
  if not ok or not cord then
    vim.notify("cord.nvim failed to setup: " .. tostring(cord), vim.log.levels.ERROR)
    return
  end
  M.cord = cord
  M.cord_initialized = true
  M.update_cord_theme()
end
return M
