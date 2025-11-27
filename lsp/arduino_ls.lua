-- /qompassai/Diver/lsp/arduino_ls.lua
-- Qompass AI Arduino LSP Spec (arduino-language-server)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local cli_config = vim.fn.expand("~/.arduino15/arduino-cli.yaml")
local cli_bin    = "arduino-cli"
local clangd_bin = "clangd"
local fqbn       = "arduino:avr:uno"
vim.lsp.config['arduino_language_server'] = {
  cmd = {
    'arduino-language-server',
    '-cli-config', cli_config,
    '-cli',        cli_bin,
    '-clangd',     clangd_bin,
    '-fqbn',       fqbn,
  },
  filetypes = { 'arduino', 'ino', 'cpp' },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor.extract', 'refactor.rewrite' },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  init_options = {},
  settings = {
    arduino = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },

  single_file_support = true,
}