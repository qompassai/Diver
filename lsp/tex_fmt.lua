-- /qompassai/Diver/lsp/tex_fmt.lua
-- Qompass AI LaTeX Formatter Spec (tex-fmt)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['tex_fmt'] = {
  cmd = { 'tex-fmt' },
  filetypes = { 'tex', 'plaintex', 'latex' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    tex_fmt = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
  on_attach = function(_client, bufnr)
    local function run_tex_fmt()
      bufnr = bufnr or vim.api.nvim_get_current_buf()

      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd('write')
      end)

      local filename = vim.api.nvim_buf_get_name(bufnr)
      if filename == '' then
        vim.notify('tex-fmt: buffer has no name', vim.log.levels.WARN)
        return
      end
      vim.fn.jobstart({ 'tex-fmt', filename }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_exit = function(_, code)
          if code == 0 then
            vim.schedule(function()
              if vim.api.nvim_buf_is_loaded(bufnr) then
                vim.cmd('edit!')
              end
            end)
          else
            vim.notify('tex-fmt: formatting failed', vim.log.levels.ERROR)
          end
        end,
        on_stderr = function(_, err)
          if err and err[1] and err[1] ~= '' then
            vim.notify('tex-fmt: ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
          end
        end,
      })
    end
    vim.keymap.set(
      'n',
      '<leader>tf',
      run_tex_fmt,
      { buffer = bufnr, desc = 'Format LaTeX with tex-fmt' }
    )
  end,
}