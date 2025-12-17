-- /qompassai/Diver/lsp/mdxana_ls.lua
-- Qompass AI MDX Analyzer LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'mdx-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'mdx',
  },
  init_options = {
    typescript = {},
  },
  root_dir = vim.fn.getcwd,
  root_markers = { ---@type string[]
    'package.json',
    'package.jsonc',
  },
  before_init = function(_, config) ---@class lsp.LSPObject.typescript
    if config.init_options and config.init_options.typescript and not config.init_options.typescript.tsdk then
      config.init_options.typescript.tsdk = vim.lsp.util.get_typescript_server_path(config.root_dir)
    end
  end,
}