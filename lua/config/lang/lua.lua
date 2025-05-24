---~/nvim/lua/config/lang/lua.lua
---------------------------------
local M = {}

local function mark_pure(src)
  return src.with({ command = "true" })
end
function M.neoconf(opts)
  opts = opts or {}
  return {
    local_settings = opts.local_settings or ".neoconf.json",
    global_settings = opts.global_settings or "neoconf.json",
    import = opts.import or { vscode = true, coc = true, nlsp = true },
    live_reload = opts.live_reload ~= false,
    filetype_jsonc = opts.filetype_jsonc ~= false,
    plugins = opts.plugins or {
      lspconfig = { enabled = true },
      jsonls = { enabled = true, configured_servers_only = true },
      lua_ls = { enabled_for_neovim_config = true, enabled = false },
    },
  }
end

function M.lua_lazydev(opts)
  opts = opts or {}
  local config = {
    runtime = vim.env.VIMRUNTIME,
    library = opts.library or {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      "LazyVim",
      vim.fn.expand("$VIMRUNTIME"),
      {
        path = vim.loop.cwd(),
        cond = function(root)
          return not vim.uv.fs_stat(root .. "/.luarc.json")
        end,
      },
    },
    integrations = {
      lspconfig = opts.integrations and opts.integrations.lspconfig ~= false,
      cmp = opts.integrations and opts.integrations.cmp ~= false,
      coq = opts.integrations and opts.integrations.coq == true,
    },
    enabled = opts.enabled or function()
      return vim.g.lazydev_enabled == nil and true or vim.g.lazydev_enabled
    end,
  }
  local ok, lazydev = pcall(require, "lazydev")
  if ok then
    lazydev.setup(config)
  end
  return config
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

function M.lua_lsp(opts)
  opts = opts or {}
  require("lspconfig").lua_ls.setup({
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        workspace = {
          library = require("neoconf").get("lua.workspace.library") or vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = true,
        },
        diagnostics = {
          globals = { "vim" },
          severity = require("neoconf").get("lua.diagnostics.severity"),
        },
        completion = {
          enable = true,
          callSnippet = "Replace",
          keywordSnippet = "Replace",
          showWord = "Fallback",
        },
        telemetry = { enable = false },
      },
    },
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lua_ls_setup", {}),
    callback = function(args)
      local ok, neoconf = pcall(require, "neoconf")
      if not ok or not neoconf._initialized then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "lua_ls" and client:supports_method("textDocument/completion") then
        vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
      end
    end,
  })
  return require("lspconfig").lua_ls
end
function M.lua_conform(opts)
  opts = opts or {}
  local base_config = require("config.lang.conform").setup(opts)
  local lua_config = {
    formatters_by_ft = {
      lua = base_config.formatters_by_ft.lua,
      luau = base_config.formatters_by_ft.luau,
    },
    formatters = {},
    format_on_save = base_config.format_on_save,
    format_after_save = base_config.format_after_save,
  }
  if base_config.formatters and base_config.formatters.stylua then
    lua_config.formatters.stylua = vim.deepcopy(base_config.formatters.stylua)
    local original_args = lua_config.formatters.stylua.prepend_args
    lua_config.formatters.stylua.prepend_args = function(self, ctx)
      local args = type(original_args) == "function" and (original_args(self, ctx) or {}) or original_args or {}
      pcall(function()
        stylua_opts = require("neoconf").get("stylua") or {}
      end)
      return vim.list_extend(args, {
        "--indent-type",
        stylua_opts.indent_type or "Spaces",
        "--indent-width",
        tostring(stylua_opts.indent_width or 2),
        "--column-width",
        tostring(stylua_opts.column_width or 100),
      })
    end
  end
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.setup({
      formatters_by_ft = {
        lua = { "stylua" },
        luau = { "stylua" },
      },
      format_on_save = opts.format_on_save and {
        lsp_fallback = "fallback",
        timeout_ms = opts.format_timeout_ms or 500,
      },
    })
  end
  return lua_config
end
function M.lua_setup(opts)
  opts = opts or {}
  local neoconf_config = M.neoconf(opts)
  require("neoconf").setup(neoconf_config)
  return {
    lsp = M.lua_lsp(opts),
    conform = M.lua_conform(opts),
    lazydev = M.lua_lazydev(opts),
  }
end
return M
