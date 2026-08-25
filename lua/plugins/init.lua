-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local api = vim.api
local add = vim.pack.add
local gh = function(x)
  return 'https://github.com/' .. x
end
--[[
local cb = function(x)
  return 'https://codeberg.org/' .. x
end
--]]
local update = vim.pack.update
local range = vim.version.range
local M = {}
vim.opt.packpath = vim.opt.runtimepath:get()
local function github(repo)
  return 'https://github.com/' .. repo
end
local plugin_setup = {}
local plugins = {
  {
    src = gh('Saghen/blink.cmp'),
    update = true,
    version = range('1.*'),
  },
  {
    src = gh('Saghen/blink.compat'),
    update = true,
    version = range('2.*'),
  },
  {
    src = gh('hrsh7th/cmp-nvim-lua'),
    update = true,
    version = 'main',
  },
  {
    src = gh('hrsh7th/cmp-buffer'),
  },
  {
    src = gh('nvim-treesitter/nvim-treesitter'),
    version = 'main',
  },
  {
    src = gh('vhyrro/luarocks.nvim'),
    update = true,
    version = 'main',
  },
  {
    src = gh('folke/which-key.nvim'),
    version = 'main',
  },
  {
    src = gh('nvim-treesitter/nvim-treesitter-textobjects'),
    version = 'main',
  },
  {
    src = gh('L3MON4D3/LuaSnip'),
    version = range('2.*'),
  },
  {
    src = gh('rafamadriz/friendly-snippets'),
    version = 'main',
  },
  {
    src = gh('moyiz/blink-emoji.nvim'),
    version = 'master',
  },
  {
    src = gh('Kaiser-Yang/blink-cmp-dictionary'),
    version = range('2.*'),
  },
  {
    src = gh('nvim-lualine/lualine.nvim'),
    version = 'master',
  },
  {
    data = {
      priority = 1000,
    },
    src = gh('olimorris/onedarkpro.nvim'),
  },
  {
    src = gh('catppuccin/nvim'),
  },
  {
    src = gh('nvim-tree/nvim-web-devicons'),
    version = 'master',
  },
  {
    src = gh('MeanderingProgrammer/render-markdown.nvim'),
    version = 'main',
  },
  {
    src = gh('EdenEast/nightfox.nvim'),
  },
  {
    src = gh('folke/tokyonight.nvim'),
    name = 'tokyonight.nvim',
  },
  {
    src = gh('marko-cerovac/material.nvim'),
  },
  {
    src = gh('Mofiqul/dracula.nvim'),
  },
  {
    src = gh('navarasu/onedark.nvim'),
    name = 'onedark.nvim',
  },
  {
    src = gh('projekt0n/github-nvim-theme'),
    name = 'github-nvim-theme',
  },
  -- { src = gh('sainnhe/gruvbox-material'), name = 'gruvbox-material' },
  {
    src = gh('shaunsingh/nord.nvim'),
    name = 'nord.nvim',
  },
  {
    src = gh('vyfor/cord.nvim'),
    data = {
      event = 'BufEnter',
      config = function()
        local opts = {}
        require('config.ui.themes').cord_setup(opts)
      end,
    },
  },
  {
    src = github('folke/flash.nvim'),
    update = true,
    version = range('2.*'),
  },
}
plugin_setup[github('Saghen/blink.cmp')] = function()
  local cmp_cfg = require('config.lang.cmp').blink_cmp()
  require('blink.cmp').setup(cmp_cfg)
end
plugin_setup[gh('nvim-treesitter/nvim-treesitter')] = function()
  require('config.core.tree').treesitter()
end

plugin_setup[gh('nvim-treesitter/nvim-treesitter-textobjects')] = function()
  require('config.core.tree').textobjects()
end
plugin_setup[github('vhyrro/luarocks.nvim')] = function()
  local ok_cfg, lua_cfg = pcall(require, 'config.lang.lua')
  if not ok_cfg or type(lua_cfg.lua_luarocks) ~= 'function' then
    vim.notify('luarocks setup: config.lang.lua.lua_luarocks missing', vim.log.levels.WARN)
    return
  end
  local ok_opts, opts = pcall(lua_cfg.lua_luarocks, {})
  if not ok_opts then
    vim.notify('luarocks setup failed: ' .. tostring(opts), vim.log.levels.ERROR)
    return
  end
  local ok_lr, lr = pcall(require, 'luarocks-nvim')
  if not ok_lr or type(lr.setup) ~= 'function' then
    vim.notify('luarocks-nvim module missing or invalid', vim.log.levels.ERROR)
    return
  end
  lr.setup(opts)
end
plugin_setup[github('folke/which-key.nvim')] = function()
  require('config.core.whichkey')
end

plugin_setup[github('nvim-lualine/lualine.nvim')] = function()
  require('config.ui.line').setup()
end

plugin_setup[github('folke/flash.nvim')] = function()
  require('config.core.flash').flash_cfg()
end
plugin_setup[gh('3rd/image.nvim')] = function()
  local ok_cfg, result = pcall(require, 'config.lang.md')

  if not ok_cfg then
    vim.notify('image.nvim setup: failed to load config.lang.md: ' .. tostring(result), vim.log.levels.ERROR)
    return
  end
  if type(result) ~= 'table' then
    vim.notify('image.nvim setup: config.lang.md must return a table', vim.log.levels.ERROR)
    return
  end
  local md_image = result.md_image
  if type(md_image) ~= 'function' then
    vim.notify('image.nvim setup: config.lang.md.md_image must be a function', vim.log.levels.WARN)
    return
  end
  local ok_setup, setup_err = xpcall(function()
    md_image({})
  end, debug.traceback)

  if not ok_setup then
    vim.notify('image.nvim setup failed:\n' .. tostring(setup_err), vim.log.levels.ERROR)
  end
end
plugin_setup[gh('3rd/diagram.nvim')] = function()
  local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
  if not ok_cfg or type(md_cfg.md_diagram) ~= 'function' then
    vim.notify('diagram.nvim setup: config.lang.md.md_diagram missing', vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(md_cfg.md_diagram, {})
  if not ok then
    vim.notify('diagram.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

plugin_setup[gh('brianhuster/live-preview.nvim')] = function()
  local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
  if not ok_cfg or type(md_cfg.md_livepreview) ~= 'function' then
    vim.notify('live-preview.nvim setup: config.lang.md.md_livepreview missing', vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(md_cfg.md_livepreview, {})
  if not ok then
    vim.notify('live-preview.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

plugin_setup[gh('arminveres/md-pdf.nvim')] = function()
  local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
  if not ok_cfg or type(md_cfg.md_pdf) ~= 'function' then
    vim.notify('md-pdf.nvim setup: config.lang.md.md_pdf missing', vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(md_cfg.md_pdf, {})
  if not ok then
    vim.notify('md-pdf.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end
plugin_setup[gh('MeanderingProgrammer/render-markdown.nvim')] = function()
  local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
  if not ok_cfg or type(md_cfg.md_rendermd) ~= 'function' then
    vim.notify('render-markdown.nvim setup: config.lang.md.md_rendermd missing', vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(md_cfg.md_rendermd, {})
  if not ok then
    vim.notify('render-markdown.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end
--[[
plugin_setup[github('echasnovski/mini.nvim')] = function()
  require('mini.ai').setup({
    custom_textobjects = {},
    n_lines = 500,
    search_method = 'cover_or_next',
  })
end
--]]
--[[
plugin_setup[github('akinsho/bufferline.nvim')] = function()
  vim.opt.termguicolors = true
  local ok, bufferline = pcall(require, 'bufferline')
  if not ok then
    vim.notify('bufferline.nvim not available: ' .. tostring(bufferline), vim.log.levels.ERROR)
    return
  end
  bufferline.setup({
    options = {
      diagnostics = 'nvim_lsp',
      always_show_bufferline = true,
      show_buffer_close_icons = false,
      show_close_icon = false,
      separator_style = 'slant',
    },
  })
end
--]]
--- @return boolean ok
--- @return string[] errors
function M.validate_specs()
  local errors = {}

  for i, spec in ipairs(plugins) do
    if type(spec) ~= 'table' then
      errors[#errors + 1] = ('plugins[%d] is not a table'):format(i)
    else
      if type(spec.src) ~= 'string' or spec.src == '' then
        errors[#errors + 1] = ('plugins[%d] is missing a valid src'):format(i)
      elseif not spec.src:match('^https://') then
        errors[#errors + 1] = ('plugins[%d].src is not a URL: %s'):format(i, spec.src)
      end

      if spec.version ~= nil and type(spec.version) ~= 'string' and type(spec.version) ~= 'table' then
        errors[#errors + 1] = ('plugins[%d].version has invalid type'):format(i)
      end
      if spec.update ~= nil and type(spec.update) ~= 'boolean' then
        errors[#errors + 1] = ('plugins[%d].update must be boolean'):format(i)
      end
    end
  end

  return #errors == 0, errors
end

--- @return table[]
function M.specs()
  return plugins
end

function M.setup_plugins()
  for _, spec in ipairs(plugins) do
    local setup = plugin_setup[spec.src]
    if type(setup) == 'function' then
      local ok, err = pcall(setup)
      if not ok then
        vim.schedule(function()
          vim.notify('Plugin setup failed for ' .. spec.src .. ': ' .. tostring(err), vim.log.levels.ERROR, {
            title = 'vim.pack',
          })
        end)
      end
    end
  end
end

function M.bootstrap()
  local ok, errors = M.validate_specs()
  if not ok then
    for _, err in ipairs(errors) do
      vim.notify(err, vim.log.levels.ERROR, {
        title = 'vim.pack spec validation',
      })
    end
    return
  end

  add(plugins, {
    confirm = false,
    load = true,
  })

  M.setup_plugins()
end

api.nvim_create_user_command('PackUpdate', function()
  vim.notify('Opening plugin update confirmation buffer…', vim.log.levels.INFO)
  update()
  api.nvim_create_autocmd('BufWritePost', {
    pattern = '*',
    once = true,
    callback = function(ev)
      if ev.buf and vim.bo[ev.buf].buftype == 'acwrite' then
        vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
      end
    end,
  })
end, {
  desc = 'Update all vim.pack plugins (interactive - :write to confirm)',
})
api.nvim_create_user_command('PackUpdateAuto', function()
  vim.notify('Updating plugins (auto-confirm)…', vim.log.levels.INFO)
  local ok, err = pcall(function()
    update(nil, { confirm = true })
  end)
  if ok then
    vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
  else
    vim.notify('Plugin update failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end, {
  desc = 'Update all vim.pack plugins (auto-confirm, no interaction)',
})
api.nvim_create_user_command('PackAdd', function(opts)
  if opts.args == '' then
    vim.notify('Usage: :PackAdd <github-user>/<repo>', vim.log.levels.WARN)
    return
  end
  local repo = opts.args
  local spec = {
    src = github(repo),
    update = true,
  }
  if type(spec.src) ~= 'string' or spec.src == '' then
    vim.notify('PackAdd failed: invalid src for ' .. repo, vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(function()
    add({
      spec,
    }, {
      confirm = false,
      load = true,
    })
  end)
  if not ok then
    vim.notify('PackAdd failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.notify('Plugin added: ' .. repo, vim.log.levels.INFO)
end, {
  nargs = 1,
  desc = 'Add a new plugin from GitHub',
})
M.bootstrap()
require('plugins.nav')
require('plugins.edu')
require('plugins.ui')
return M
