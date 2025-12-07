-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['lua_ls'] = {
  cmd = {
    'lua-language-server',
  },
  codeActionProvider = {
    codeActionKinds = {
      '',
      'quickfix',
      'refactor.rewrite',
      'refactor.extract',
    },
    resolveProvider = true,
  },
  colorProvider = true,
  filetypes = {
    'lua',
    "luau",
  },
  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = {
        'async',
        'bstract',
        'declaration',
        'defaultLibrary',
        'definition',
        'deprecated',
        'documentation',
        'global',
        'modification',
        'readonly',
        'static'
      },
      tokenTypes = {
        'class',
        'comment',
        'decorator',
        'enum',
        'enumMember',
        'event',
        'function',
        'interface',
        'keyword',
        'macro',
        'method',
        'modifier',
        'namespace',
        'number',
        'operator',
        'parameter',
        'property',
        'regexp',
        'struct',
        'typeParameter',
        'string',
        'type',
        'variable'
      },
    },
    range = true,
  },
  root_markers = {
    '.luarc.json',
    ".luarc.jsonc",
    ".luarc.json5",
    ".stylua.toml",
    "luacheckrc",
    ".luacheckrc",
  },
  settings = {
    Lua = {
      format = {
        enable = true,
        defaultConfig = {
          align_continuous_rect_table_field = true,
          align_array_table = true,
          indent_style = 'tabs',
          indent_size = '4',
          quote_style = 'ForceSingle',
          trailing_table_separator = 'always',
          align_continuous_assign_statement = true,
        },
      },
      runtime = {
        version = 'LuaJIT',
        path = {
          'lua/?.lua',
          'lua/?/init.lua',
        },
      },
      diagnostics = {
        enable = true,
        globals = {
          'vim',
          'jit',
          'use',
          'require',
        },
        disable = {
          'lowercase-global',
          'unused-local'
        },
        severity = {
          -- ['unused-local'] = 'Hint',
        },
        unusedLocalExclude = {
          '_*',
        },
      },
      workspace = {
        checkThirdParty = true,
        library = {
          vim.api.nvim_get_runtime_file('', true),
          vim.env.VIMRUNTIME,
          '${3rd}/luv/library',
          '${3rd}/busted/library',
          '${3rd}/neodev.nvim/types/nightly',
          '${3rd}/luassert/library',
          '${3rd}/lazy.nvim/library',
          '${3rd}/blink.cmp/library',
          vim.fn.expand("$HOME") .. '/.config/nvim/lua/',
        },
        ignoreDir = {
          'node_modules',
          'build'
        },
        maxPreload = 2000,
        preloadFileSize = 50000,
      },
      telemetry = {
        enable = false,
      },
      completion = {
        callSnippet = 'Replace',
        keywordSnippet = 'Enable',
        displayContext = 4,
      },
      hint = {
        enable = true,
        setType = true,
        paramType = true,
        paramName = 'All',
        arrayIndex = 'Enable',
        await = true,
      },
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = true
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function(args)
        vim.lsp.buf.format({
          async = false,
          bufnr = args.buf,
          filter = function(c)
            return c.name == 'lua_ls'
          end,
        })
      end,
    })
  end,
}