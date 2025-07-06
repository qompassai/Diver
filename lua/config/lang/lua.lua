-- qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local conform_cfg = require('config.lang.conform')
local U = require("utils.lang.lua")
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

function M.lua_conform()
  local by_ft = conform_cfg.conform_cfg().formatters_by_ft
  local seen, res = {}, {}
  for _, ft in ipairs({ by_ft.lua or {}, by_ft.luau or {} }) do
    for _, f in ipairs(ft) do
      if not seen[f] then seen[f] = true; res[#res+1] = f end
    end
  end
  return res
end

function M.lua_lazydev(opts)
  opts = opts or {}
  return {
    runtime      = vim.env.VIMRUNTIME,
    library      = U.lua_library({ { path = U.lua_home() } }),
    integrations = {
      lspconfig = opts.integrations and opts.integrations.lspconfig ~= false,
      cmp       = opts.integrations and opts.integrations.cmp       ~= false,
      coq       = opts.integrations and opts.integrations.coq       ~= false,
    },
    enabled = opts.enabled or function() return vim.g.lazydev_enabled ~= false end,
  }
end

function M.lua_lsp(opts)
  opts = opts or {}
  local ver, bin   = U.lua_version()
  local runtime    = U.lua_runtime(bin:gsub("/bin/lua$", ""))
  local is_jit     = ver:lower():find("jit") ~= nil
  local lua_ls = {
    on_attach    = opts.on_attach,
    capabilities = opts.capabilities,
    filetypes    = opts.filetypes or { "lua", "luau" },
    settings = {
      Lua = {
        runtime = { version = is_jit and "LuaJIT" or ver, path = runtime },
        workspace = {
          library        = vim.tbl_extend("force",
                             vim.api.nvim_get_runtime_file("", true),
                             { vim.fn.stdpath("config") .. "/lua/types",
                               U.lua_home() }),
          checkThirdParty = true,
        },
        diagnostics = {
          globals = { "vim","require","jit","cmp","luassert",
                      "use_blink_cmp","lazydev_enabled","blink_cmp" },
          disable = { "missing-fields" },
        },
        completion = { callSnippet = "Replace", keywordSnippet = "Disable" },
        telemetry  = { enable = false },
      },
    },
  }
  return lua_ls
end

function M.lua_luarocks(opts)
  opts = opts or {}
  local config = {
    rocks_path = vim.fn.expand('~/.luarocks'),
    rocks = {
      "magick",
      "busted",
      "luacheck",
      "fzy",
    },
  }
  return vim.tbl_deep_extend('force', config, opts)
end

function M.lua_nls(opts)
  opts = opts or {}
  local nls   = require('null-ls')
  local b     = nls.builtins
  local style = U.find_config(".stylua.toml")
  return {
    mark_pure(b.code_actions.refactoring),
    mark_pure(b.completion.luasnip),
    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space),
    b.diagnostics.selene.with({ ft = { "lua","luau" } }),
    b.diagnostics.teal  .with({ ft = { "teal" } }),
    b.formatting.stylua .with({
      ft = { "lua","luau" },
      command = "stylua",
      extra_args = { "--config-path", style },
    }),
  }
end
function M.lua_snap(opts)
  opts = opts or {}
  local config = { mappings = { ['<CR>'] = 'submit', ['<C-x>'] = 'cut' } }
  return vim.tbl_deep_extend('force', config, opts)
end

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

function M.lua_cfg(opts)
  local ver, bin = U.lua_version()
  vim.env.LUA_VERSION = ver
  vim.env.LUA_PATH    = bin
  return {
    autocmds  = M.lua_autocmds,
    cmp       = M.lua_cmp,
    conform   = M.lua_conform(),
    lazydev   = M.lua_lazydev(opts or {}),
    lsp       = M.lua_lsp(opts or {}),
    luarocks  = M.lua_luarocks(opts or {}),
    nls       = M.lua_nls(opts or {}),
    snap      = M.lua_snap(opts or {}),
    test      = M.lua_test(opts or {}),
    version   = ver,
    path      = bin,
  }
end

return M
