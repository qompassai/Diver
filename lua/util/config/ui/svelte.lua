-- ~/.config/nvim/lua/config/ui/svelte.lua
local M = {}

function M.svelte_lsp(opts)
  local lspconfig = require("lspconfig")
  lspconfig.svelte.setup({
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    filetypes = { "svelte" },
    settings = {
      svelte = {
        plugin = {
          typescript = {
            diagnostics = true,
            hover = true,
            completions = true,
            definitions = true,
            findReferences = true,
            codeActions = true
          }
        }
      }
    }
  })
end

function M.astro_lsp(opts)
  local lspconfig = require("lspconfig")
  lspconfig.astro.setup({
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    filetypes = { "astro" }
  })
end

function M.svelte_treesitter(opts)
  opts = opts or {}
  opts.ensure_installed = opts.ensure_installed or {}
  if type(opts.ensure_installed) == "table" then
    vim.list_extend(opts.ensure_installed, { "svelte", "typescript", "javascript", "astro" })
  end
  return opts
end

function M.svelte_conform(opts)
  opts = opts or {}
  opts.formatters_by_ft = opts.formatters_by_ft or {}
  opts.formatters_by_ft.svelte = { "prettierd" }
  opts.formatters_by_ft.astro = { "prettierd" }
  return opts
end

return M
