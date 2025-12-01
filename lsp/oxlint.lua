-- /qompassai/Diver/lsp/oxlint.lua
-- Qompass AI Javascript Oxidation Lint (oxlint) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://www.npmjs.com/package/oxlint | https://oxc.rs/docs/guide/usage/linter/cli.html
local util = require("lspconfig.util")
vim.lsp.config['oxlint'] = {
  cmd = {
    'oxlint',
    "--config=.oxlintrc.json",
    "-D",
    "correctness",
    "-D",
    "suspicious",
    "-W",
    "style",
    "--type-aware",
    "--type-check",
    "--import-plugin",
    "--react-plugin",
    "--tsconfig=tsconfig.json",
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root_markers = util.insert_package_json({
      ".oxlintrc.json",
    }, "oxlint", fname)
    local found = vim.fs.find(root_markers, {
      path = fname,
      upward = true,
    })[1]
    if found then
      on_dir(vim.fs.dirname(found))
    end
  end,
}