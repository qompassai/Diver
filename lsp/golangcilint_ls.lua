-- /qompassai/Diver/lsp/golangci_lint_ls.lua
-- Qompass AI Go-lang CI Lint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------------------
-- go install github.com/nametake/golangci-lint-langserver@latest
-- go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
vim.lsp.config['golangcilint_ls'] = {
  cmd = {
    'golangci-lint-langserver'
  },
  filetypes = {
    'go',
    'gomod',
  },
  init_options = {
    command = {
      'golangci-lint',
      'run',
      '--output.json.path=stdout',
      '--show-stats=false',
    },
  },
  root_markers = {
    '.golangci.yml',
    '.golangci.yaml',
    '.golangci.toml',
    '.golangci.json',
    'go.work',
    'go.mod',
    '.git',
  },
  before_init = function(_, config)
    local v1, v2 = false, false
    if vim.fn.executable('go') == 1 and vim.fn.executable('golangci-lint') == 1 then
      local exe = vim.fn.exepath('golangci-lint')
      if exe ~= '' then
        local result = vim.system({ 'go', 'version', '-m', exe }):wait()
        if result.code == 0 and result.stdout then
          v1 = string.match(result.stdout, '\tmod\tgithub.com/golangci/golangci%-lint\t') ~= nil
          v2 = string.match(result.stdout, '\tmod\tgithub.com/golangci/golangci%-lint/v2\t') ~= nil
        end
      end
    end
    if not v1 and not v2 and vim.fn.executable('golangci-lint') == 1 then
      local result = vim.system({ 'golangci-lint', 'version' }):wait()
      if result.code == 0 and result.stdout then
        v1 = string.match(result.stdout, 'version v?1%.') ~= nil
      end
    end
    if v1 then
      config.init_options.command = {
        'golangci-lint',
        'run',
        '--out-format',
        'json'
      }
    end
  end,
}