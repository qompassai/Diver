-- /qompassai/Diver/lsp/dotenv_linter.lua
-- Qompass AI Dotenv Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['dotenv_linter'] = {
  cmd = { 'dotenv-linter' },
  filetypes = { 'dotenv', 'sh' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    dotenv = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
  on_attach = function(_client, bufnr)
    local function run_dotenv_linter()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == '' then
        vim.notify('dotenv-linter: buffer has no name', vim.log.levels.WARN)
        return
      end
      vim.fn.jobstart({ 'dotenv-linter', '--format', 'github', filename }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if not data then return end
          local qf = {}
          for _, line in ipairs(data) do
            if line ~= '' then
              local f, l, c, sev, msg = line:match('^(.-):(%d+):(%d+):%s*(%w+):%s*(.*)')
              if f and l and c and sev and msg then
                table.insert(qf, {
                  filename = f,
                  lnum = tonumber(l),
                  col = tonumber(c),
                  text = msg,
                  type = (sev == 'error') and 'E' or 'W',
                })
              end
            end
          end
          if #qf > 0 then
            vim.fn.setqflist(qf, 'r')
            vim.cmd('copen')
          else
            vim.notify('dotenv-linter: no issues', vim.log.levels.INFO)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= '' then
            vim.notify('dotenv-linter: ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
          end
        end,
      })
    end
    vim.keymap.set('n', '<leader>el', run_dotenv_linter, { buffer = bufnr, desc = 'Lint .env with dotenv-linter' })
  end,
}
