-- ruby.lua
-- Qompass AI Ruby Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd(
  'BufWritePre', ---Ruby
  {
    pattern = {
      '*.rb',
      '*.rake',
      'Gemfile',
      'Rakefile',
    },
    callback = function(args) ---@param args { buf: integer }
      vim.lsp.buf.format({
        async = false,
        bufnr = args.buf,
        filter = function(client)
          return client.name == 'ruby-lsp'
        end,
      })
    end,
  }
)