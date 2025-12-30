-- /qompassai/Diver/lua/config/lang/arduino.lua
-- Qompass AI Diver Arduino Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd('FileType',
  {
    pattern = 'arduino',
    group = vim.api.nvim_create_augroup('Arduino',
      {}),
    callback = function(ev)
      local bufnr = ev.buf
      vim.bo[bufnr].expandtab = true
      vim.bo[bufnr].shiftwidth = 2
      vim.bo[bufnr].tabstop = 2
      vim.bo[bufnr].commentstring = '// %s'
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>ab',
        [[:!arduino-cli compile --fqbn arduino:avr:uno .<CR>]],
        { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>au',
        [[:!arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno .<CR>]],
        {
          noremap = true,
          silent = true
        })
    end,
  })
vim.api.nvim_create_autocmd('LspAttach',
  {
    group = vim.api.nvim_create_augroup('NoSemTokens',
      {}),
    callback = function(ev)
      local bufnr = ev.buf
      local client_id = ev.data and ev.data.client_id
      if not client_id then
        return
      end
      local client = vim.lsp.get_client_by_id(client_id)
      if not client or client.name ~= 'arduino_ls' then
        return
      end
      client.server_capabilities.semanticTokensProvider = nil
      vim.bo[bufnr].formatexpr = nil
    end,
  })