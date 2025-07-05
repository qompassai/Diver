-- qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local conform_cfg = require('config.lang.conform')
---@module 'types.lang.lua'
local M = {}
local function mark_pure(src) return src.with({ command = 'true' }) end
function M.lua_autocmds()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'lua',
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.expandtab = true
    end
  })
end

---@return table
function M.lua_cmp()
  if vim.g.use_blink_cmp then
    return {
      sources = {
        { name = 'lsp' }, { name = 'luasnip' }, { name = 'buffer' },
        { name = 'nvim_lua', via = 'compat' }, { name = 'lazydev' }
      },
      performance = { async = true, throttle = 50 },
      appearance = {
        kind_icons = require('lazyvim.config').icons.kinds,
        nerd_font_variant = 'mono',
        use_nvim_cmp_as_default = false
      },
      completion = {
        accept = { auto_brackets = true },
        menu = { draw = { treesitter = { 'lsp' } } },
        documentation = { auto_show = true }
      }
    }
  else
    return {
      snippet = {
        expand = function(args)
          local luasnip = require('luasnip')
          luasnip.lsp_expand(args.body)
        end
      },
      mapping = require('cmp').mapping.preset.insert({
        ['<C-b>'] = require('cmp').mapping.scroll_docs(-4),
        ['<C-f>'] = require('cmp').mapping.scroll_docs(4),
        ['<C-Space>'] = require('cmp').mapping.complete(),
        ['<C-e>'] = require('cmp').mapping.abort(),
        ['<CR>'] = require('cmp').mapping.confirm({ select = true })
      }),
      sources = {
        { name = 'nvim_lua' }, { name = 'nvim_lsp' }, { name = 'luasnip' },
        { name = 'buffer' }
      },
      experimental = { ghost_text = true }
    }
  end
end

---@param opts? table
---@return table
function M.lua_conform(opts)
  opts = opts or {}
  local cfg = conform_cfg.conform_cfg().formatters_by_ft
  local seen, result = {}, {}
  for _, ft in ipairs({ cfg.lua or {}, cfg.luau or {} }) do
    for _, f in ipairs(ft) do
      if not seen[f] then
        seen[f] = true
        table.insert(result, f)
      end
    end
  end
  return result
end

function M.lua_lazydev(opts)
  opts = opts or {}
  vim.g = vim.g or {}
  local lua_version_path = nil
    local function default(v, d) return v == nil and d or v end
  local versions = { 'luajit', 'lua51', 'lua54', 'lua52', 'lua53' }
  for _, version in ipairs(versions) do
    local path = vim.fn.expand('"$HOME"/.diver/lua/.' .. version)
    if vim.fn.isdirectory(path) == 1 then
      lua_version_path = path
      break
    end
  end
  local library = {
    { path = '${3rd}/luv/library',                  words = { 'vim%.uv' } }, { path = 'LazyVim' },
    { path = tostring(vim.fn.expand('$VIMRUNTIME')) },
    { path = vim.fn.stdpath('config') .. '/lua' },
    { path = vim.fn.stdpath('config') .. '/types' },
    { path = vim.fn.stdpath('data') .. '/lazy' }
  }
  if lua_version_path then
    table.insert(library, { path = lua_version_path })
    table.insert(library, {
      path = lua_version_path .. '/share/lua/5.4',
      words = { 'require' }
    })
    table.insert(library, {
      path = lua_version_path .. '/lib/lua/5.4',
      words = { 'require' }
    })
  end
  if not vim.uv.fs_stat(vim.loop.cwd() .. '/.luarc.json5') then
    table.insert(library, { path = tostring(vim.loop.cwd()) })
  end

  for i, entry in ipairs(library) do
    assert(type(entry.path) == 'string', 'Library entry ' .. i ..
      ' has invalid path type: ' .. type(entry.path))
  end
  return {
   runtime = vim.env.VIMRUNTIME,
    library = library,

    integrations = {
      lspconfig = default(opts.integrations and opts.integrations.lspconfig, true),
      cmp       = default(opts.integrations and opts.integrations.cmp,       true),
      coq       = default(opts.integrations and opts.integrations.coq,      false),
    },
    enabled = default(opts.enabled, function()
      return vim.g.lazydev_enabled ~= false
    end),
  }
end
function M.lua_lsp(opts)
  opts = opts or {}
  local lspconfig = require('lspconfig')
  local lua_version, lua_path = M.lua_version()
  local is_luajit = (lua_version:lower():find('jit') or jit) and true or false
  local runtime_paths = {
    '?.lua', '?/init.lua',
    lua_path and (lua_path .. '/share/lua/5.4/?.lua') or nil,
    lua_path and (lua_path .. '/share/lua/5.4/?/init.lua') or nil,
    lua_path and (lua_path .. '/share/lua/5.1/?.lua') or nil,
    lua_path and (lua_path .. '/share/lua/5.1/?/init.lua') or nil,
    vim.fn.stdpath('config') .. '/lua/?.lua',
    vim.fn.stdpath('config') .. '/lua/?/init.lua'
  }
  local config = {
    settings = {
      Lua = {
        runtime = {
          version = is_luajit and 'LuaJIT' or lua_version,
          path = vim.tbl_filter(function(p)
            return p ~= nil
          end, runtime_paths)
        },
        workspace = {
  library = vim.tbl_extend(
    'force',
    vim.api.nvim_get_runtime_file('', true),
    { vim.fn.stdpath('config') .. '/lua/types' }
  ),
  checkThirdParty = true,
},
        diagnostics = {
          globals = {
            'vim', 'use_blink_cmp', 'lazydev_enabled', 'require',
            'blink_cmp', 'cmp', 'luassert', 'jit'
          },
          disable = { 'missing-fields' }
        },
        completion = {
          callSnippet = 'Replace',
          keywordSnippet = 'Disable'
        },
        telemetry = { enable = false }
      }
    },
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    filetypes = opts.filetypes or { 'lua', 'luau' }
  }
  if opts.settings then
    config.settings = vim.tbl_deep_extend('force', config.settings,
      opts.settings)
  end
  lspconfig.lua_ls.setup(config)
end

---@param opts? table
---@return table
function M.lua_luarocks(opts)
  opts = opts or {}
  local config = {
    rocks_path = vim.fn.expand('~/.luarocks'),
    rocks = {
      "magick",
      "busted",
      "luacheck",
    },
  }
  return vim.tbl_deep_extend('force', config, opts)
end

---@param opts? table
---@return table
function M.lua_nls(opts)
  opts = opts or {}
  local null_ls = require('null-ls')
  local b = null_ls.builtins
  local stylua_config_path = opts.stylua_config_path or
      vim.fn
      .expand('$HOME/.config/nvim/.stylua.toml')
  local selene_args = opts.selene_args or { '--display-style', 'quiet', '-' }
  local teal_args = opts.teal_args or { 'check', '$FILENAME' }
  return {
    mark_pure(b.code_actions.refactoring), mark_pure(b.completion.luasnip),
    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space), b.diagnostics.selene.with({
    ft = { 'lua', 'luau' },
    command = 'selene',
    extra_args = selene_args
  }), b.diagnostics.teal.with({
    ft = { 'teal' },
    command = 'teal',
    extra_args = teal_args
  }), b.formatting.stylua.with({
    ft = { 'lua', 'luau' },
    command = 'stylua',
    extra_args = { '--config-path', stylua_config_path }
  })
  }
end

---@param opts? table
---@return table
function M.lua_snap(opts)
  opts = opts or {}
  local config = { mappings = { ['<CR>'] = 'submit', ['<C-x>'] = 'cut' } }
  return vim.tbl_deep_extend('force', config, opts)
end

---@param opts? table
---@return table
function M.lua_test(opts)
  opts = opts or {}
  return {
    adapters = {
      require('neotest-plenary')({
        test_file_patterns = { '.*_test%.lua$', '.*_spec%.lua$' },
        min_init = 'tests/init.lua'
      })
    },
    strategies = {
      integrated = {
        args = { '--lua', vim.fn.expand('~/.diver/.lua/.lua51/bin/lua') }
      }
    },
    output_panel = { open = 'botright split | resize 15' },
    discovery = {
      enabled = true,
      filter_dir = function(name)
        return name ~= 'node_modules' and name ~= '.git'
      end
    }
  }
end

---@return string, string
function M.lua_version()
  local versions = { 'luajit', 'lua54', 'lua53', 'lua52', 'lua51' }
  for _, version in ipairs(versions) do
    local path = vim.fn.expand('~/.diver/.lua/.' .. version) .. '/bin/lua'
    if vim.fn.filereadable(path) == 1 then return version, path end
  end
  return 'LuaJIT', vim.fn.exepath('lua')
end

---@class LuaSetupReturn
---@field cmp fun(): table
---@field conform table
---@field lazydev table
---@field lsp fun(opts?: table)
---@field luarocks table
---@field nls table[]
---@field version string
---@field path string
---@field snap table
---@field test table
---@field neoconf table

---@param opts? table
---@return LuaSetupReturn
function M.lua_setup(opts)
  opts = opts or {}
  local lua_version, lua_path = M.lua_version()
  vim.env.LUA_VERSION = lua_version
  vim.env.LUA_PATH = lua_path
  return {
    autocmds = M.lua_autocmds,
    cmp = M.lua_cmp,
    conform = M.lua_conform(opts),
    lazydev = M.lua_lazydev(opts),
    lsp = M.lua_lsp(opts),
    luarocks = M.lua_luarocks(opts),
    nls = M.lua_nls(opts),
    version = lua_version,
    path = lua_path,
    snap = M.lua_snap(opts),
    test = M.lua_test(opts),
  }
end

return M
