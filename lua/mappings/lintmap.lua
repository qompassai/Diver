-- ~/.config/nvim/lua/mappings/lintmap.lua
-- ---------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {}

function M.setup_lintmap()
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true }

  map("n", "<leader>ll", function()
    require("lint").try_lint()
  end, vim.tbl_extend("force", opts, { desc = "Run linter" }))

  map("n", "<leader>lL", "<cmd>LintWith ", vim.tbl_extend("force", opts, { desc = "Run specific linter" }))

  map("n", "<leader>li", function()
    local lint = require("lint")
    local ft = vim.bo.filetype
    local linters = lint.linters_by_ft[ft] or {}
    if #linters == 0 then
      vim.notify("No linters configured for filetype: " .. ft, vim.log.levels.INFO)
    else
      vim.notify("Available linters: " .. table.concat(linters, ", "), vim.log.levels.INFO)
    end
  end, vim.tbl_extend("force", opts, { desc = "Show available linters" }))

  map("n", "<leader>lf", function()
    require("conform").format({ async = true }, function()
      require("lint").try_lint()
    end)
  end, vim.tbl_extend("force", opts, { desc = "Format and lint" }))

  map("n", "<leader>lc", function()
    vim.diagnostic.reset()
  end, vim.tbl_extend("force", opts, { desc = "Clear diagnostics" }))
end

return M
