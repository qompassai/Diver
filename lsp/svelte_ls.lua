-- /qompassai/Diver/lsp/svelte_ls.lua
-- Qompass AI Svelte LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/sveltejs/language-tools/tree/master/packages/language-server
-- pnpm add -g svelte-language-server
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'svelteserver',
    '--stdio',
  },
  filetypes = {
    'svelte',
  },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if vim.uv.fs_stat(fname) ~= nil then
      local root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', 'deno.lock' }
      root_markers = vim.fn.has('nvim-0.11.3') == 1 and { root_markers, { '.git' } }
          or vim.list_extend(root_markers, { '.git' })
      local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()
      on_dir(project_root)
    end
  end,
  root_markers = {
    'bun.lock',
    'bun.lockb',
    'deno.lock',
    '.git',
    'package-lock.json',
    'pnpm-lock.yaml',
    'yarn.lock',
  },
  initializationOptions = {
    configuration = {
      svelte = {
        plugin = {
          typescript = {
            enable = true,
            diagnostics = {
              enable = true,
            },
            hover = {
              enable = true,
            },
            documentSymbols = {
              enable = true,
            },
            completions = {
              enable = true,
            },
            codeActions = {
              enable = true,
            },
            selectionRange = {
              enable = true,
            },
            signatureHelp = {
              enable = true,
            },
            semanticTokens = {
              enable = true,
            },
            workspaceSymbols = {
              enable = true,
            },
          },
          css = {
            enable = true,
            diagnostics = {
              enable = true,
            },
            hover = {
              enable = true,
            },
            completions = {
              enable = true,
              emmet = true,
            },
            documentColors = {
              enable = true,
            },
            colorPresentations = {
              enable = true,
            },
            documentSymbols = {
              enable = true,
            },
            selectionRange = {
              enable = true,
            },
            globals = 'src/styles/global.css,src/styles/tokens.css',
          },
          html = {
            enable = true,
            hover = {
              enable = true,
            },
            completions = {
              enable = true,
              emmet = true,
            },
            tagComplete = {
              enable = true,
            },
            documentSymbols = {
              enable = true,
            },
            linkedEditing = {
              enable = true,
            },
          },
          svelte = {
            enable = true,
            diagnostics = {
              enable = true,
            },
            compilerWarnings = {
              ['css-unused-selector'] = 'ignore',
              ['unused-export-let'] = 'error',
            },
            format = {
              enable = true,
              config = {
                svelteSortOrder = 'options-scripts-markup-styles',
                svelteStrictMode = false,
                svelteAllowShorthand = true,
                svelteBracketNewLine = true,
                svelteIndentScriptAndStyle = true,
                printWidth = 100,
                singleQuote = false,
              },
            },
            hover = {
              enable = true,
            },
            completions = {
              enable = true,
            },
            rename = {
              enable = true,
            },
            codeActions = {
              enable = true,
            },
            selectionRange = {
              enable = true,
            },
            runesLegacyModeCodeLens = {
              enable = true,
            },
            defaultScriptLanguage = 'ts',
            documentHighlight = {
              enable = true,
            },
          },
        },
      },
      typescript = {},
      javascript = {},
      prettier = {},
      emmet = {},
      css = {},
    },
  },
  on_attach = function(client, bufnr)
    local group = vim.api.nvim_create_augroup('lspconfig.svelte', {
      clear = false,
    })
    vim.api.nvim_create_autocmd('BufWritePost', {
      pattern = {
        '*.js',
        '*.ts',
      },
      group = group,
      callback = function(ctx)
        ---@diagnostic disable-next-line: param-type-mismatch
        client:notify('$/onDidChangeTsOrJsFile', {
          uri = ctx.match,
        })
      end,
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspMigrateToSvelte5', function()
      client:exec_cmd({
        title = 'Migrate Component to Svelte 5 Syntax',
        command = 'migrate_to_svelte_5',
        arguments = { vim.uri_from_bufnr(bufnr) },
      })
    end, {
      desc = 'Migrate Component to Svelte 5 Syntax',
    })
  end,
}