local M       = {}
local null_ls = require("null-ls")
local b       = null_ls.builtins

local function mark_pure(src) return src.with({ command = "true" }) end

function M.neoconf_opts()
  return {
    local_settings  = ".neoconf.json",
    global_settings = "neoconf.json",
    live_reload     = true,
    filetype_jsonc  = true,
    plugins = {
      lspconfig = { enabled = true },
      jsonls    = { enabled = true, configured_servers_only = true },
      lua_ls    = { enabled_for_neovim_config = true, enabled = true },
    },
  }
end

function M.none_ls_sources()
  return {
    mark_pure(b.code_actions.refactoring),
    mark_pure(b.completion.luasnip),
    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space),
    b.diagnostics.selene.with({ extra_args = { "--display-style", "quiet", "-" } }),
    b.diagnostics.teal.with({ extra_args = { "check", "$FILENAME" } }),
    b.formatting.stylua.with({
      extra_args = { "--config-path", vim.fn.expand("$HOME/.config/nvim/.stylua.toml") },
    }),
  }
end

function M.lazydev_opts()
  return {
    types   = true,
   library = {
  { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  { path = "LazyVim" },
  { path = vim.fn.expand("$VIMRUNTIME") },
  {
    path = vim.loop.cwd(),
    cond = function(root)
      return not vim.uv.fs_stat(root .. "/.luarc.json")
    end,
  },
},
    integrations = { lspconfig = true, cmp = true, coq = false },
  }
end

function M.setup_lsp(on_attach, capabilities)
  require("lspconfig").lua_ls.setup({
    on_attach    = on_attach,
    capabilities = capabilities,
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        workspace = {
          library = require("neoconf").get("lua.workspace.library")
            or vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = true,
        },
        diagnostics = {
          globals  = { "vim" },
          severity = require("neoconf").get("lua.diagnostics.severity"),
        },
        completion = { callSnippet = "Replace" },
        telemetry  = { enable = false },
      },
    },
  })
end

function M.setup_all(opts)
  opts = opts or {}
  M.setup_lsp(opts.on_attach, opts.capabilities)
  M.none_ls_sources()
  M.neoconf_opts()
  return M.lazydev_opts()
end

return M

