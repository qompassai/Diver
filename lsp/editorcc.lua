-- /qompassai/Diver/lsp/editorconfig_checker.lua
-- Qompass AI EditorConfig Compliance Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['editorconfig_checker'] = {
  cmd = { 'editorconfig-checker' },
  filetypes = { '*', 'lua', 'go', 'python', 'javascript', 'typescript', 'markdown', 'yaml', 'json', 'sh' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    editorconfig_checker = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
  on_attach = function(_client, bufnr)
    local function run_editorconfig_checker()
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == '' then
        vim.notify('editorconfig-checker: buffer has no name', vim.log.levels.WARN)
        return
      end

      -- Restrict scan to the current file: `editorconfig-checker -file <path>`.[web:996][web:1002]
      local cmd = { 'editorconfig-checker', '-file', filename }

      vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if not data or #data == 0 then
            vim.notify('editorconfig-checker: no issues', vim.log.levels.INFO)
            return
          end
          local qf = {}
          for _, line in ipairs(data) do
            if line ~= '' then
              local f, l, msg = line:match('^(.-):(%d+):%s*(.*)')
              if not f then
                f, msg = line:match('^(.-):%s*(.*)')
              end
              if f and msg then
                table.insert(qf, {
                  filename = f,
                  lnum     = tonumber(l) or 1,
                  col      = 1,
                  text     = msg,
                  type     = 'W',
                })
              end
            end
          end

          if #qf > 0 then
            vim.fn.setqflist(qf, 'r')
            vim.cmd('copen')
          else
            vim.notify('editorconfig-checker: no issues', vim.log.levels.INFO)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= '' then
            vim.notify('editorconfig-checker: ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
          end
        end,
      })
    end
    vim.keymap.set(
      'n',
      '<leader>ec',
      run_editorconfig_checker,
      { buffer = bufnr, desc = 'Check file against .editorconfig' }
    )
  end,
}
