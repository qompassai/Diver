-- /qompassai/Diver/lsp/zls.lua
-- Qompass AI ZLS LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function find_executable(names)
  for _, name in ipairs(names) do
    local paths = {
      vim.fn.expand("~") .. '/.local/bin',
      vim.fn.stdpath('data') .. '/mason/bin',
      vim.env.PATH or ''
    }
    for _, path in ipairs(vim.split(table.concat(paths, ':'), ':')) do
      local exe = vim.fn.exepath(path .. '/' .. name)
      if exe ~= '' then return exe end
    end
  end
end

local zls_path = find_executable({ 'zls' }) or 'zls'
local zig_path = find_executable({ 'zig' }) or 'zig'

vim.lsp.config['zls'] = {
  cmd = { zls_path },
  filetypes = { 'zig', 'zon', 'ziggy', 'zine' },
  settings = {
    zls = {
      enable_ast_check_diagnostics = true,
      enable_build_on_save = true,
      zig_exe_path = zig_path,
      enable_inlay_hints = true,
      inlay_hints = {
        parameter_names = true,
        variable_names = true,
        builtin = true,
        type_names = true,
      },
    },
  },
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
    if client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(bufnr, true)
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function() vim.lsp.buf.format({ async = false }) end,
    })
  end,
  flags = { debounce_text_changes = 150 },
  single_file_support = true,
}