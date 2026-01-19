-- /qompassai/Diver/after/ftplugin/bash.lua
-- Qompass AI Diver After Filetype Bash Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd('BufWritePre',
  {
    pattern = {
      '*.bash',
      '*.sh'
    },
    callback = function(args)
      vim.lsp.buf.format({
        bufnr = args.buf,
        async = true,
      })
    end,
  })