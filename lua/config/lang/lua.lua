---~/nvim/lua/config/lang/lua.lua
---------------------------------
local M = {}
local function mark_pure(src)
  return src.with({ command = "true" })
end
function M.lua_conform(opts)
  opts = opts or {}
  local base_config = require("config.lang.conform").conform_setup(opts)
  local lua_config = {
    formatters_by_ft = {
      lua = base_config.formatters_by_ft.lua,
      luau = base_config.formatters_by_ft.luau,
    },
    formatters = {},
    format_on_save = base_config.format_on_save,
    format_after_save = base_config.format_after_save,
  }
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.setup({
      formatters_by_ft = {
        lua = { "stylua", "lua-format" },
        luau = { "stylua", "lua-format" },
      },
      format_on_save = opts.format_on_save and {
        lsp_fallback = "fallback",
        timeout_ms = opts.format_timeout_ms or 500,
      },
    })
  end
  return lua_config
end
function M.lua_cmp()
  return {
    snippet = {
      expand = function(args)
        local luasnip = require('luasnip')
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = require('mappings.luamap').setup_luamap(),
    sources = {
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
      { name = 'omni' },
      { name = 'buffer' },
    },
    experimental = {
      ghost_text = true,
    },
  }
end
function M.lua_lazydev(opts)
  opts = opts or {}
  vim.g = vim.g or {}
  local lua_version_path = nil
  local versions = {"luajit", "lua51", "lua54", "lua52", "lua53"}
  for _, version in ipairs(versions) do
    local path = vim.fn.expand("~/.diver/.lua/." .. version)
    if vim.fn.isdirectory(path) == 1 then
      lua_version_path = path
      break
    end
  end
  local library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    { path = "LazyVim" },
    { path = tostring(vim.fn.expand("$VIMRUNTIME")) },
  }
  if lua_version_path then
    table.insert(library, { path = lua_version_path })
    table.insert(library, {
      path = lua_version_path .. "/share/lua/5.4",
      words = { "require" }
    })
    table.insert(library, {
      path = lua_version_path .. "/lib/lua/5.4",
      words = { "require" }
    })
  end
  if not vim.uv.fs_stat(vim.loop.cwd() .. "/.luarc.json") then
    table.insert(library, { path = tostring(vim.loop.cwd()) })
  end

  for i, entry in ipairs(library) do
    assert(type(entry.path) == "string",
           "Library entry "..i.." has invalid path type: "..type(entry.path))
  end
  return {
    runtime = vim.env.VIMRUNTIME,
    library = library,
    integrations = {
      lspconfig = opts.integrations and opts.integrations.lspconfig ~= true,
      cmp = opts.integrations and opts.integrations.cmp ~= true,
      coq = opts.integrations and opts.integrations.coq == true,
    },
    enabled = opts.enabled or function()
      return vim.g.lazydev_enabled ~= false
    end,
  }
end
function M.lua_lsp(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local lua_version, lua_path = M.lua_version()
  local config = {
    settings = {
      Lua = {
        runtime = {
          version = lua_version,
          path = {
            "?.lua",
            "?/init.lua",
            lua_path and (lua_path .. "/share/lua/5.4/?.lua") or nil,
            lua_path and (lua_path .. "/share/lua/5.4/?/init.lua") or nil
          }
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = true,
        },
        diagnostics = {
          globals = { "vim" },
        },
        telemetry = { enable = false },
      }
    },
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    filetypes = opts.filetypes or { "lua", "luau" },
  }
  if opts.settings then
    config.settings = vim.tbl_deep_extend("force", config.settings, opts.settings)
  end
  lspconfig.lua_ls.setup(config)
end
function M.lua_luarocks(opts)
  opts = opts or {}
  local config = {
    rocks_path = vim.fn.expand('~/.luarocks'),
  }
  return vim.tbl_deep_extend('force', config, opts)
end
function M.lua_nls(opts)
  opts = opts or {}
  local null_ls = require("null-ls")
  local b = null_ls.builtins
  local stylua_config_path = opts.stylua_config_path or vim.fn.expand("$HOME/.config/nvim/.stylua.toml")
  local selene_args = opts.selene_args or { "--display-style", "quiet", "-" }
  local teal_args = opts.teal_args or { "check", "$FILENAME" }
  return {
    mark_pure(b.code_actions.refactoring),
    mark_pure(b.completion.luasnip),
    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space),
    b.diagnostics.selene.with({
      ft = { "lua", "luau" },
      command = "selene",
      extra_args = selene_args,
    }),
    b.diagnostics.teal.with({
      ft = { "teal" },
      command = "teal",
      extra_args = teal_args,
    }),
    b.formatting.stylua.with({
      ft = { "lua", "luau" },
      command = "stylua",
      extra_args = { "--config-path", stylua_config_path },
    }),
  }
end
function M.lua_snap(opts)
  opts = opts or {}
  local config = {
    mappings = {
      ['<CR>'] = 'submit',
      ['<C-x>'] = 'cut',
    },
  }
  return vim.tbl_deep_extend('force', config, opts)
end
function M.lua_version()
  local versions = {"luajit", "lua54", "lua53", "lua52", "lua51"}
  for _, version in ipairs(versions) do
    local path = vim.fn.expand("~/.diver/.lua/." .. version) .. "/bin/lua"
    if vim.fn.filereadable(path) == 1 then
      return version, path
    end
  end
  return "LuaJIT", vim.fn.exepath("lua")
end
function M.lua_neoconf(opts)
  opts = opts or {}
  return {
    local_settings = ".neoconf.json",
    global_settings = "neoconf.json",
    import = {
      vscode = true,
      coc = true,
      nlsp = true,
    },
    live_reload = true,
    filetype_jsonc = true,
    plugins = opts.plugins or {
      lspconfig = {
        enabled = true,
      },
      jsonls = {
        enabled = true,
        configured_servers_only = true,
      },
      lua_ls = {
        enabled_for_neovim_config = true,
        enabled = true,
      },
    },
  }
end
function M.lua_setup(opts)
  opts = opts or {}
  local neoconf_config = M.lua_neoconf(opts)
  require("neoconf").setup(neoconf_config)
  local lua_version, lua_path = M.lua_version()
  vim.env.LUA_VERSION = lua_version
  vim.env.LUA_PATH = lua_path
  return {
    cmp = M.lua_cmp,
    conform = M.lua_conform(opts),
    lazydev = M.lua_lazydev(opts),
    lsp = M.lua_lsp,
    luarocks = M.lua_luarocks,
    nls = M.lua_nls(opts),
    version = lua_version,
    path = lua_path,
    snap = M.lua_snap,
    neoconf = neoconf_config
  }
end
return M
