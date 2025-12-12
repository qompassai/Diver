-- /qompassai/Diver/lsp/emmylua_ls.lua
-- Qompass AI Emmyluals Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: ttps://github.com/EmmyLuaLs/emmylua-analyzer-rust
--cargo install emmylua_ls
vim.lsp.config['emmylua_ls'] = {
  cmd = {
    'emmylua_ls',
    '-c',
    'stdio',
    '--editor',
    'neovim',
    '--log-level',
    'info',
  },
  filetypes = {
    'lua',
  },
  root_markers = {
    '.emmylua.json',
    '.luarc.json',
    '.luarc.json',
    '.luacheckrc',
  },
  workspace_required = false,
  settings = {
    Emmylua = {
      completion = {
        callSnippet = 'Both',
        displayContext = 4,
        enable = true,
        keywordSnippet = 'Both'
      },
      diagnostics = {
        disable = {
          'lowercase-global',
          'unused-local'
        },
        enable = true,
        globals = {
          'jit',
          'require',
          'use',
          'vim',
        },
        severity = {
          ['deprecated'] = 'Error',
        },
        unusedLocalExclude = {
          '_*',
        },
      },
      format = {
        defaultConfig = {
          align_continuous_assign_statement = true,
          indent_size = '4',
          indent_style = 'tab',
          quote_style = 'ForceSingle',
          trailing_table_separator = 'never',
        },
        enable = true,
      },
      hint = {
        arrayIndex = 'Enable',
        await = true,
        enable = true,
        paramName = 'All',
        paramType = true,
        setType = true,
      },
      runtime = {
        version = 'LuaJIT',
          requireLikeFunction = {
          'import',
          'load',
          'dofile'
        },
      },
      telemetry = {
        enable = false,
      },
      workspace = {
        checkThirdParty = true,
        encoding = 'utf-8',
        ignoreDir = {
          'build',
          'node_modules',
          'dist'
        },
        library = {
          vim.api.nvim_get_runtime_file('', true),
          vim.env.VIMRUNTIME,
          '${3rd}/busted/library',
          '${3rd}/luv/library',
          '${3rd}/luassert/library',
          '${3rd}/lazy.nvim/library',
          '${3rd}/neodev.nvim/types/nightly',
          '${3rd}/blink.cmp/library',
          vim.fn.expand('$HOME') .. '/.config/nvim/lua/',
        },
        maxPreload = 1000,
        preloadFileSize = 10000,
      },
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
  end,
}