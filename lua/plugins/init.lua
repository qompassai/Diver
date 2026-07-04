-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local api = vim.api
local add = vim.pack.add
local update = vim.pack.update
local range = vim.version.range
local tree = require('config.core.tree')
local M = {}
vim.opt.packpath = vim.opt.runtimepath:get()
local function github(repo)
  return 'https://github.com/' .. repo
end
local plugin_setup = {}
local plugins = {
  {
    src = github('Saghen/blink.cmp'),
    update = true,
    version = range('1.*'),
  },
  {
    src = github('akinsho/bufferline.nvim'),
    update = true,
    version = 'main',
  },
  {
    src = github('nvim-treesitter/nvim-treesitter'),
    update = true,
  },
  {
    src = github('vhyrro/luarocks.nvim'),
    branch = 'main',
    update = true,
  },
  {
    src = github('folke/which-key.nvim'),
    update = true,
    version = 'main',
  },
  {
    src = github('nvim-treesitter/nvim-treesitter-textobjects'),
    update = true,
    version = 'main',
  },
  {
    src = github('L3MON4D3/LuaSnip'),
    version = range('2.*'),
  },
  {
    src = github('rafamadriz/friendly-snippets'),
    update = true,
    version = 'main',
  },
  {
    src = github('hrsh7th/cmp-nvim-lua'),
    update = true,
    version = 'main',
  },
  {
    src = github('hrsh7th/cmp-buffer'),
  },
  {
    src = github('moyiz/blink-emoji.nvim'),
    version = 'master',
  },
  {
    src = github('Kaiser-Yang/blink-cmp-dictionary'),
    update = true,
    version = range('2.*'),
  },
  {
    src = github('nvim-lualine/lualine.nvim'),
    update = true,
    version = 'master',
  },
  {
    src = github('nvim-tree/nvim-web-devicons'),
    update = true,
  },
  {
    src = github('Saghen/blink.compat'),
    update = true,
    version = range('2.*'),
  },
  {
    src = github('folke/flash.nvim'),
    update = true,
    version = range('2.*'),
  },
  {
    src = github('echasnovski/mini.nvim'),
    update = true,
    version = range('0.*'),
  },
}
plugin_setup[github('Saghen/blink.cmp')] = function()
  local cmp_cfg = require('config.lang.cmp').blink_cmp()
  require('blink.cmp').setup(cmp_cfg)
end
plugin_setup[github('nvim-treesitter/nvim-treesitter')] = function()
  tree.treesitter({})
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

plugin_setup[github('echasnovski/mini.nvim')] = function()
  require('mini.ai').setup({
    custom_textobjects = {},
    n_lines = 500,
    search_method = 'cover_or_next',
  })
end
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
          vim.notify(
            'Plugin setup failed for ' .. spec.src .. ': ' .. tostring(err),
            vim.log.levels.ERROR,
            { title = 'vim.pack' }
          )
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
    add({ spec }, {
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
return M
