local null_ls = require("null-ls")
local M = {}

function M.null_ls_sources()
  return {
    --null_ls.builtins.code_actions.refactoring.with({
    -- ft = { "go", "javascript", "lua", "python", "typescript" },
    --}),
    --null_ls.builtins.completion.luasnip.with({
    --  ft = { "lua" },
    --}),
    --require("none-ls-luacheck.diagnostics.luacheck").with({
    --  ft = { "lua" },
    --}),
    null_ls.builtins.diagnostics.selene.with({
      ft = { "lua", "luau" },
      extra_args = { "--display-style", "quiet", "-" },
    }),
    null_ls.builtins.diagnostics.todo_comments,
    null_ls.builtins.diagnostics.trail_space,
    null_ls.builtins.formatting.stylua.with({
      filetypes = { "lua", "luau" },
      extra_args = {
        "--config-path",
        vim.fn.expand("$HOME/.config/nvim/.stylua.toml"),
      },
    }),
    null_ls.builtins.diagnostics.teal.with({
      ft = { "teal" },
      extra_args = function(params)
        if type(params.bufname) ~= "string" then
          return { "check", "/dev/null" } -- fallback to dummy input
        end
        return { "check", params.bufname }
      end,
    }),
  }
end
function M.setup(on_attach, capabilities)
  local lazydev = require("lazydev")
  lazydev.setup({
    library = {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      vim.env.VIMRUNTIME,
    },
    integrations = {
      lspconfig = true,
      cmp = true,
    },
    enabled = function(root_dir)
      return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
    end,
  })

  local lspconfig = require("lspconfig")
  require("lspconfig").lua_ls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    handlers = {
      ["workspace/didChangeWatchedFiles"] = vim.lsp.handlers["workspace/didChangeWatchedFiles"],
    },
    on_init = function(client)
      if client.server_capabilities.didChangeWatchedFiles then
        client.config.flags = client.config.flags or {}
        client.config.flags.watchFiles = false
      end
    end,
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = vim.split(package.path, ";"),
        },
        diagnostics = {
          globals = { "vim" },
          disable = { "missing-fields" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = false,
        },
        telemetry = {
          enable = false,
        },
      },
    },
    flags = {
      debounce_text_changes = 150,
    },
  })
end

return M
