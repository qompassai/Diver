-- /qompassai/Diver/lsp/trufflehog.lua
-- Qompass AI Secrets Scan Spec (trufflehog CLI)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['trufflehog'] = {
  cmd = { 'trufflehog' },
  filetypes = { 'gitcommit', 'yaml', 'json', 'jsonc', 'sh', 'bash', 'zsh', 'terraform', 'dockerfile', '*' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    trufflehog = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
  on_attach = function(_client, bufnr)
    local function run_trufflehog_filesystem()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local cwd = vim.fn.getcwd()
      local cmd = { 'trufflehog', 'filesystem', cwd, '--fail', '--json' }
      vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if not data or #data == 0 then return end
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, data)
          vim.api.nvim_set_current_buf(buf)
          vim.bo[buf].filetype = 'json'
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= '' then
            vim.notify('trufflehog: ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
          end
        end,
      })
    end
    vim.keymap.set(
      'n',
      '<leader>ts',
      run_trufflehog_filesystem,
      { buffer = bufnr, desc = 'Scan cwd for secrets with trufflehog' }
    )
  end,
}