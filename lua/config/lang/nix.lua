-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'config.lang.nix'
local M = {} ---@class NixLangConfig

---@param opts? table
function M.nix_autocmds(opts) ---@return nil
  opts = opts or {}
  vim.api.nvim_create_user_command("SetNixFormatter", function(args)
    vim.g.nix_formatter = args.args
  end, {
    nargs = 1,
    complete = function()
      return { "alejandra", "nixfmt", "nixpkgs-fmt" }
    end,
  })
end

function M.nix_conform()
  local by_ft = require("config.lang.conform").conform_cfg().formatters_by_ft("nix")
  local seen, res = {}, {}
  for _, ft in ipairs({ by_ft.nix or {} }) do
    for _, f in ipairs(ft) do
      if not seen[f] then
        seen[f] = true
        res[#res + 1] = f
      end
    end
  end
  return res
end

---@param opts? table
---@return table
function M.nls(opts)
  opts = opts or {}
  local nlsb = require("null-ls").builtins
  local sources = {
    nlsb.formatting.alejandra,
    nlsb.diagnostics.deadnix,
    nlsb.diagnostics.statix,
  }
  return sources
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
function M.nix_cfg(opts)
  opts = opts or {}
  return {
    autocmds = M.nix_autocmds(opts),
    conform = M.nix_conform(),
    nls = M.nls(opts),
  }
end

return M
