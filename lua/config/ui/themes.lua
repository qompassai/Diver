-- /qompassai/Diver/lua/config/ui/themes.lua
-- Qompass AI Diver Themes Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta
---@module 'config.ui.themes'
local M = {}
M.current_theme = 'nightfox' ---@type string
M.themes = {
  catppuccin = {
    setup = function()
      require('catppuccin').setup({
        flavour = 'mocha',
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
      vim.cmd.colorscheme('catppuccin')
    end,
    discord_name = 'Catppuccin',
    discord_icon = '🍧',
  },
  tokyonight = {
    setup = function()
      require('tokyonight').setup({
        options = {
          sidebars = {
            'qf',
            'help'
          },
          lualine_bold = true,
          nvimtree = true,
          gitsigns = true,
          treesitter = true,
          lualine = true,
          bufferline = true,
          notify = true,
          indent_blankline = {
            enabled = true,
            colored_indent_levels = true
          },
          dashboard = true,
          whichkey = true,
          neotree = true,
          styles = {
            keywords = 'bold',
          },
          transparent = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme('tokyonight')
    end,
    discord_name = 'Tokyo Night',
    discord_icon = '🗼',
  },
  onedark = {
    setup = function()
      require('onedark').setup({
        options = {
          style = 'deep',
          transparent = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme('onedark')
    end,
    discord_name = 'One Dark',
    discord_icon = '🌑',
  },
  gruvbox = {
    setup = function()
      vim.g.gruvbox_material_background = 'medium'
      vim.g.gruvbox_material_enable_bold = 1
      vim.g.gruvbox_material_enable_italic = 0
      vim.g.gruvbox_material_transparent_background = 1
    end,
    apply = function()
      vim.cmd.colorscheme('gruvbox-material')
    end,
    discord_name = 'Gruvbox Material',
    discord_icon = '🧸',
  },
  nightfox = {
    setup = function()
      require('nightfox').setup({
        options = {
          compile_path = vim.fn.stdpath('cache') .. '/nightfox',
          compile_file_suffix = '_compiled',
          terminal_colors = true,
          transparent = true,
          dim_inactive = false,
          styles = {
            keywords = 'bold',
            types = 'bold',
          },
        },
        integrations = {
          indent_blankline = {
            enabled = true,
            colored_indent_levels = true,
          },
          nvimtree = true,
          gitsigns = true,
          telescope = true,
          lualine = true,
          notify = true,
          cmp = true,
          neotree = true,
          dashboard = true,
          whichkey = true,
          native_lsp = {
            enabled = true,
          },
          treesitter = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme('nightfox')
    end,
    discord_name = 'Nightfox',
    discord_icon = '🦊',
  },
  nord = {
    setup = function()
      vim.g.nord_transparent = true
    end,
    apply = function()
      vim.cmd.colorscheme('nord')
    end,
    discord_name = 'Nord',
    discord_icon = '❄️',
  },
  material = {
    setup = function()
      require('material').setup({
        contrast = {
          sidebars = true,
          floating_windows = true,
        },
        styles = {
          comments = {
            italic = false,
          },
          keywords = {
            bold = true,
          },
        },
        disable = {
          background = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme('material')
    end,
    discord_name = 'Material',
    discord_icon = '🎨',
  },
  dracula = {
    setup = function()
      require('dracula').setup({
        transparent_bg = true
      })
    end,
    apply = function()
      vim.cmd.colorscheme('dracula')
    end,
    discord_name = 'Dracula',
    discord_icon = '🧛',
  },
  github = {
    setup = function()
      require('github-theme').setup({
        transparent = true,
      })
    end,
    apply = function()
      vim.cmd.colorscheme('github_dark')
    end,
    discord_name = 'GitHub Dark',
    discord_icon = '🐙',
  },
  onedarkpro = {
    setup = function()
      require('onedarkpro').setup({
        dark_theme = 'onedark_vivid',
        options = {
          transparency = true,
        },
      })
    end,
    apply = function()
      vim.cmd.colorscheme('onedark_vivid')
    end,
    discord_name = 'OneDark Pro',
    discord_icon = '⚫',
  },
}
function M.set_theme(theme_name)
  local theme = M.themes[theme_name]
  if not theme then
    vim.echo('Theme not found: ' .. theme_name, vim.log.levels.ERROR)
    return false
  end
  local ok_setup, err_setup = pcall(theme.setup)
  if not ok_setup then
    vim.echo('Failed to set up theme ' .. theme_name .. ': ' .. err_setup, vim.log.levels.ERROR)
    return false
  end
  local ok_apply, err_apply = pcall(theme.apply)
  if not ok_apply then
    vim.echo('Failed to apply theme: ' .. err_apply, vim.log.levels.ERROR)
    return false
  end
  M.current_theme = theme_name
  if M.discord_initialized then
    M.update_cord_theme()
  end
  return true
end

function M.apply_current_theme(opts)
  opts = opts or {}
  return M.set_theme(M.current_theme)
end

function M.update_cord_theme(opts)
  opts = opts or {}
  local theme = M.themes[M.current_theme]
  if not theme or not M.cord_initialized or not M.cord then
    return opts
  end
  M.cord:update_presence({
    custom_details = 'Using ' .. theme.discord_name .. ' theme ' .. theme.discord_icon,
  })
end

function M.setup_appearance(opts)
  opts = opts or {}
  return {
    theme = M.current_theme,
    icon = M.themes[M.current_theme].discord_icon or '🎨',
    text = 'Using ' .. M.themes[M.current_theme].discord_name,
  }
end

function M.setup_cord(opts)
  opts = opts or {}
  local cord_mod = require('cord')
  local instance = cord_mod.setup({
    assets = M.cord_assets(),
    editor = { client = 'neovim', tooltip = 'The Superior Text Editor' },
    advanced = {
      plugin = {
        cursor_update = 'on_hold',
      },
    },
    server = {
      update = 'fetch',
    },
    appearance = M.setup_appearance(),
    text = M.setup_text(),
    buttons = M.setup_buttons(),
    idle = M.cord_idle().idle,
    timestamp = M.cord_idle().timestamp,
    hooks = M.setup_hooks().hooks,
  })
  return instance
end

function M.cord_idle(opts)
  opts = opts or {}
  return {
    idle = {
      state_text = 'AFK',
      details_text = 'Idle in Neovim',
      timeout = 300,
    },
    timestamp = {
      reset_on_idle = true
    },
  }
end

function M.cord_assets(opts)
  opts = opts or {}
  return {
    file_assets = function()
      if opts.filename then
        if opts.filename:match('%.lua$') then
          return {
            type = 'language',
            icon = 'lua',
            text = 'Lighting up with Lua',
          }
        elseif opts.filename:match('%.rs$') then
          return {
            type = 'language',
            icon = 'rust',
            text = 'Rocking out with Rust',
          }
        elseif opts.filename:match('%.md?$') or opts.filename:match('%.markdown$') then
          return {
            type = 'language',
            icon = 'markdown',
            text = 'Making it in Markdown',
          }
        end
      end
      if opts.filetype == 'lua' then
        return {
          type = 'language',
          icon = 'lua',
          text = 'Lighting it up with Lua',
        }
      elseif opts.filetype == 'rust' then
        return {
          type = 'language',
          icon = 'rust',
          text = 'Rocking it in Rust',
        }
      elseif opts.filetype == 'markdown' then
        return {
          type = 'language',
          icon = 'markdown',
          text = 'Writing Markdown',
        }
      end
      return {
        type = 'language',
        text = 'Editing ' .. (opts.filetype or 'file'),
      }
    end,
  }
end

function M.setup_text()
  return {
    editing = function(opts)
      if opts.filetype == 'lua' then
        return 'Scripting in Lua: ' .. opts.filename
      elseif opts.filetype == 'rust' then
        return '🦀 Crafting in Rust: ' .. opts.filename
      else
        return 'Editing ' .. opts.filename
      end
    end,
    watching = 'Viewing ${filename}',
    workspace = function(opts)
      local hour = tonumber(os.date('%H'))
      local status = hour >= 22 and '🌙 Late night coding'
          or hour >= 18 and '🌆 Evening session'
          or hour >= 12 and '☀️ Afternoon coding'
          or hour >= 5 and '🌅 Morning productivity'
          or '🌙 Midnight hacking'
      return string.format('%s: %s', status, opts.workspace or 'Unknown project')
    end,
  }
end

function M.setup_buttons()
  return {
    buttons = function(opts)
      local buttons = {}
      if opts.repo_url then
        table.insert(buttons,
          {
            label = 'View Repository',
            url = opts.repo_url ---@type string
          })
      end
      table.insert(buttons, {
        label = 'Neovim Website',
        url = 'https://neovim.io'
      })
      return buttons
    end,
  }
end

function M.setup_hooks(opts)
  opts = opts or {}
  return {
    hooks = {
      on_idle = function(activity)
        activity.details = 'Away from keyboard'
      end,
    },
  }
end

function M.cord_setup(opts)
  opts = opts or {}
  local ok, themes = pcall(require, 'config.ui.themes')
  if not ok then
    vim.echo('Failed to load theme config: ' .. tostring(themes), vim.log.levels.ERROR)
    return
  end
  if not themes.apply_current_theme() then
    return
  end
  local setup_ok, cord = pcall(themes.setup_cord)
  if not setup_ok then
    vim.echo('Cord setup failed: ' .. tostring(cord), vim.log.levels.ERROR)
    return
  end
  M.apply_current_theme(opts)
  M.setup_cord(opts)
  M.cord_initialized = true
  M.setup_hooks(opts)
  M.update_cord_theme()
end

return M