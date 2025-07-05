-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'config.lang.nix'
---@type NixLangConfig

local M = {}
local function mark_pure(src) return src.with({ command = 'true' }) end

function M.nix_autocmds(opts)
  opts = opts or {}
vim.api.nvim_create_user_command("SetNixFormatter", function(args)
  vim.g.nix_formatter = args.args
end, { nargs = 1, complete = function()
  return { "alejandra", "nixfmt", "nixpkgs-fmt" }
end })

end

---@param opts? { formatter?: string }
---@return NixConformConfig
function M.nix_conform(opts)
  opts = opts or {}
  local formatter = opts.formatter or "alejandra"
  return {
    formatters_by_ft = {
      nix = { formatter },
    },
    format_on_save = { lsp_fallback = true },
    format_after_save = { enabled = true },
  }
end


---@param opts? table
---@return table
function M.nix_nls(opts)
  opts = opts or {}
  local null_ls = require('null-ls')
  local b = null_ls.builtins
  return {
    b.formatting.alejandra, mark_pure(b.diagnostics.deadnix),
    mark_pure(b.diagnostics.statix)
  }
end

---@param opts? table
---@return table
function M.nix_lsp(opts)
  opts = opts or {}
  return {
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    settings = {
      ['nil_ls'] = {
        formatting = { command = 'nixpkgs-fmt' },
        diagnostics = {
          enabled = true,
          ignored = { 'unused_binding' },
          excludedFiles = {}
        },
        nix = {
          flake = { autoArchive = true, autoEvalInputs = true },
          autoLSPConfig = true
        }
      }
    }
  }
end

function M.vim_nix_config()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "nix",
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.expandtab = true
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "nix",
    callback = function()
      vim.keymap.set("n", "<leader>ne", ":NixEdit<Space>", { buffer = true, desc = "NixEdit attribute" })
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "nix",
    callback = function()
      vim.opt_local.conceallevel = 2
    end,
  })
end

---@param opts? table
---@return { conform: NixConformConfig, nls: table, lsp: table }
function M.nix_cfg(opts)
  opts = opts or {}
  return {
    autocmds =  M.nix_autocmds(opts),
    conform = M.nix_conform(opts),
    nls = M.nix_nls(opts),
    lsp = M.nix_lsp(opts)
  }
end

return M
