-- /qompassai/Diver/lsp/phan.lua
-- Qompass AI Phan LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['phan'] = {
  cmd = {
    'phan',
    '-m',
    'json',
    "--no-color",
    "--no-progress-bar",
    "-x",
    "-u",
    "-S",
    "--language-server-on-stdin",
    "--allow-polyfill-parser"
  },
  filetypes = {
    'php'
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local cwd = assert(vim.uv.cwd())
    local root = vim.fs.root(fname, { "composer.json", ".git" })
    on_dir(root and vim.fs.relpath(cwd, root) and cwd)
  end,
}