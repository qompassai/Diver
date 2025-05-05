---~/nvim/lua/config/lang/lua.lua
---------------------------------
local M = {}
---
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
---@param opts table|nil
---@return table
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
        end
      }
    },
    integrations = {
      lspconfig = opts.integrations and opts.integrations.lspconfig ~= nil
        and opts.integrations.lspconfig or true,
      cmp = opts.integrations and opts.integrations.cmp ~= nil
        and opts.integrations.cmp or true,
      coq = opts.integrations and opts.integrations.coq ~= nil
        and opts.integrations.coq or false,
    },

    enabled = opts.enabled or function(root_dir)
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
  vim.lsp.config["luals"] = {
    command = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
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
  }
  vim.lsp.enable("luals")
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lua_ls_setup", {}),
    callback = function(args)
      local neoconf_ok = pcall(require, "neoconf")
      if not neoconf_ok then
        return
      end
      local neoconf = require("neoconf")
      if not neoconf._initialized then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "luals" then
        if client:supports_method("textDocument/completion") then
          vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
        end
      end
    end,
  })
  return vim.lsp.config["luals"]
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
  }

  if base_config.formatters and base_config.formatters.stylua then
    lua_config.formatters.stylua = vim.deepcopy(base_config.formatters.stylua)
    local original_prepend_args = lua_config.formatters.stylua.prepend_args
    lua_config.formatters.stylua.prepend_args = function(self, ctx)
      local base_args = {}
      if type(original_prepend_args) == "function" then
        base_args = original_prepend_args(self, ctx) or {}
      elseif type(original_prepend_args) == "table" then
        base_args = original_prepend_args
      end
      local stylua_opts = {}
      pcall(function()
        stylua_opts = require("neoconf").get("stylua") or {}
      end)
      return {
        "--indent-type", stylua_opts.indent_type or "Spaces",
        "--indent-width", tostring(stylua_opts.indent_width or 2),
        "--column-width", tostring(stylua_opts.column_width or 100),
      }
    end
  end
  lua_config.format_on_save = base_config.format_on_save
  lua_config.format_after_save = base_config.format_after_save
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
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
  local lsp_config = M.lua_lsp(opts)
  local conform_config = M.lua_conform(opts)
  local lazydev_config = M.lua_lazydev(opts)
  return {
    lsp = lsp_config,
    conform = conform_config,
    lazydev = lazydev_config
  }
end
