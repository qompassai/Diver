-- /qompassai/Diver/lsp/svelte_ls.lua
-- Qompass AI Svelte LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/sveltejs/language-tools/tree/master/packages/language-server
-- pnpm add -g svelte-language-server
vim.lsp.config['svelte_ls'] = {
  cmd = {
    'svelteserver',
    '--stdio'
  },
  filetypes = {
    'svelte'
  },
  root_markers = {
    'bun.lock',
    'bun.lockb',
    'deno.lock',
    '.git',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
  },
  initializationOptions = {
    configuration = {
      svelte = {
        plugin = {
          typescript = {
            enable = true,
            diagnostics = {
              enable = true
            },
            hover = {
              enable = true
            },
            documentSymbols = {
              enable = true
            },
            completions = {
              enable = true
            },
            codeActions = {
              enable = true
            },
            selectionRange = {
              enable = true
            },
            signatureHelp = {
              enable = true
            },
            semanticTokens = {
              enable = true
            },
            workspaceSymbols = {
              enable = true
            },
          },
          css = {
            enable = true,
            diagnostics = {
              enable = true
            },
            hover = {
              enable = true
            },
            completions = {
              enable = true,
              emmet = true,
            },
            documentColors = {
              enable = true
            },
            colorPresentations = {
              enable = true
            },
            documentSymbols = {
              enable = true
            },
            selectionRange = {
              enable = true
            },
            globals = 'src/styles/global.css,src/styles/tokens.css',
          },
          html = {
            enable = true,
            hover = {
              enable = true
            },
            completions = {
              enable = true,
              emmet = true,
            },
            tagComplete = {
              enable = true
            },
            documentSymbols = {
              enable = true
            },
            linkedEditing = {
              enable = true
            },
          },
          svelte = {
            enable = true,
            diagnostics = {
              enable = true
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
              enable = true
            },
            completions = {
              enable = true
            },
            rename = {
              enable = true
            },
            codeActions = {
              enable = true
            },
            selectionRange = {
              enable = true
            },
            runesLegacyModeCodeLens = {
              enable = true
            },
            defaultScriptLanguage = 'ts',
            documentHighlight = {
              enable = true
            },
          },
        },
      },
      typescript = {
      },
      javascript = {
      },
      prettier = {
      },
      emmet = {
      },
      css = {
      },
    },
  },
  on_attach = function(client, bufnr)
    local group = vim.api.nvim_create_augroup('lspconfig.svelte',
      {
        clear = false
      })
    vim.api.nvim_create_autocmd('BufWritePost',
      {
        pattern = {
          '*.js',
          '*.ts'
        },
        group = group,
        callback = function(ctx)
          ---@diagnostic disable-next-line: param-type-mismatch
          client:notify('$/onDidChangeTsOrJsFile',
            {
              uri = ctx.match
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
      desc = 'Migrate Component to Svelte 5 Syntax'
    })
  end,
}