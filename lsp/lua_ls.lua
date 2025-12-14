-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['lua_ls'] = {
  cmd = {
    'lua-language-server'
  },
  filetypes = {
    'lua',
    'luau'
  },
  root_markers = {
    '.emmyrc.json',
    '.luarc.json',
    '.luarc.jsonc',
    '.luarc.json5',
    'luacheckrc',
    '.luacheckrc',
    '.stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git'
  },
  settings = {
    Lua = {
      codeLens = {
        enable = true
      },
      format = {
        enable = true,
        defaultConfig = {
          align_array_table = true,
          align_continuous_assign_statement = true,
          align_continuous_rect_table_field = true,
          indent_size = '4',
          indent_style = 'tabs',
          quote_style = 'ForceSingle',
          trailing_table_separator = 'never',
        },
      },
      hover = {
        previewfields = 50
      },
      runtime = {
        version = 'LuaJIT',
        path = {
          'lua/?.lua',
          'lua/?/init.lua'
        },
      },
      semantic = {
        enable = true,
        keyword = true
      },
      diagnostics = {
        enable = true,
        globals = {
          'vim',
          'jit',
          'use',
          'require'
        },
        disable = {
          'lowercase-global',
          'unused-local'
        },
        severity = {
          ['unused-local'] = 'Hint'
        },
        unusedLocalExclude = {
          '_*'
        },
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.api.nvim_get_runtime_file('', true),
          vim.env.VIMRUNTIME,
          -- '${3rd}/luv/library',
          -- '${3rd}/busted/library',
          -- '${3rd}/neodev.nvim/types/nightly',
          -- '${3rd}/luassert/library',
          '${3rd}/lazy.nvim/library',
          -- '${3rd}/blink.cmp/library',
          vim.fn.expand('$HOME') .. '/.config/nvim/lua/',
        },
        ignoreDir = {
          'build',
          'node_modules',
          '.vscode'
        },
        maxPreload = 5000,
        preloadFileSize = 500,
        useGitIgnore = true,
      },
      telemetry = {
        enable = false
      },
      completion = {
        autoRequire = true,
        callSnippet = 'Both',
        displayContext = 1,
        enable = true,
        keywordSnippet = 'Both',
        postfix = '@',
      },
      hint = {
        arrayIndex = 'Enable',
        enable = true,
        setType = true,
        paramType = true,
        paramName = 'All',
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
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
          path ~= vim.fn.stdpath('config')
          and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
      then
        return
      end
    end
    client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
      Lua = {
        runtime = { version = 'LuaJIT' },
      },
    })
  end,
}