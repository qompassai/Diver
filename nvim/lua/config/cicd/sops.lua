-- /qompassai/Diver/lua/config/cicd/sops.lua
-- Qompass AI CICD Sops Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.sops(_)
  if vim.fn.executable("sops") == 0 then
    vim.notify("sops.nvim: sops binary not found in $PATH", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_create_autocmd({ "BufReadPre", "FileReadPre" }, {
    pattern = {
      ".sops.yaml",
      ".sops.yml",
      ".sops.json",
      ".enc",
      ".secret.yaml",
      ".secret.json",
      ".sops.yaml",
      ".sops.yml",
      ".sops.json",
    },
    callback = function(ev)
      vim.b[ev.buf].sops_encrypted = true
    end,
  })
  vim.api.nvim_create_user_command("SopsToggle", function()
    vim.b.sops_encrypted = not vim.b.sops_encrypted
    vim.notify("sops.nvim: buffer sops_encrypted = " .. tostring(vim.b.sops_encrypted))
  end, { desc = "Toggle SOPS encryption for current buffer" })
end
return M