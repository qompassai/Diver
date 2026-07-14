-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Diver Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'biome',
    'lsp-proxy',
  },
  filetypes = {
    'astro',
    'cjs',
    'css',
    'graphql',
    'html',
    'javascript',
    'javascriptreact',
    'json',
    'jsonc',
    -- 'markdown',
    'mdx',
    'mjs',
    'spajson',
    'svelte',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
    'vue',
  },
  root_markers = {
    'bun.lock',
    'bun.lockb',
    '.git',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
  },

  on_attach = function(client, bufnr)
    local group = vim.api.nvim_create_augroup('BiomeWriteActions', { clear = false })

    vim.api.nvim_clear_autocmds({
      group = group,
      buffer = bufnr,
    })

    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      buffer = bufnr,
      callback = function()
        local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
        params.context = { only = { 'source.organizeImports.biome', 'source.fixAll.biome' } }

        local result = vim.lsp.buf_request_sync(bufnr, 'textDocument/codeAction', params, 3000)

        if result then
          for _, res in pairs(result) do
            for _, action in pairs(res.result or {}) do
              if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
              end

              local command = action.command or action
              if command and command.command then
                client:exec_cmd(command, { bufnr = bufnr })
              end
            end
          end
        end

        if client.server_capabilities.documentFormattingProvider then
          vim.lsp.buf.format({
            bufnr = bufnr,
            async = false,
            timeout_ms = 3000,
            filter = function(c)
              return c.id == client.id
            end,
          })
        end
      end,
    })
  end,
  settings = {
    biome = {
      require_configuration = false,
      configuration_path = nil,
      go_to_definition = true,
      configuration = {
        ['$schema'] = 'https://biomejs.dev/schemas/2.5.3/schema.json',
        files = {
          ignoreUnknown = false,
          maxDiagnostics = 1000,
        },
        formatter = {
          attributePosition = 'auto',
          enabled = true,
          formatWithErrors = true,
          indentStyle = 'space',
          indentWidth = 2,
          lineEnding = 'lf',
          lineWidth = 160,
        },
        linter = {
          enabled = true,
          domains = {
            next = 'all',
            test = 'all',
          },
          rules = {
            recommended = true,
            correctness = {
              noUndeclaredDependencies = 'error',
              noUnusedVariables = 'error',
              noUnusedImports = 'error',
            },
            nursery = {
              noFloatingPromises = 'error',
            },
            style = {
              noInferrableTypes = 'error',
              noParameterAssign = 'error',
              noUnusedTemplateLiteral = 'error',
              noUselessElse = 'error',
              useAsConstAssertion = 'error',
              useConst = 'error',
              useDefaultParameterLast = 'error',
              useEnumInitializers = 'error',
              useNumberNamespace = 'error',
              useSelfClosingElements = 'error',
              useSingleVarDeclarator = 'error',
              useTemplate = 'error',
            },
            suspicious = {
              noVar = 'error',
            },
          },
        },
        organizeImports = {
          enabled = true,
          javascript = {
            enabled = true,
          },
          typescript = {
            enabled = true,
          },
        },
        overrides = {
          {
            includes = { '**/*.svelte', '**/*.astro', '**/*.vue' },
            linter = {
              enabled = true,
              domains = {
                next = 'all',
                test = 'all',
              },
              rules = {
                style = {
                  useConst = 'off',
                  useImportType = 'off',
                },
                correctness = {
                  noUnusedVariables = 'off',
                  noUnusedImports = 'off',
                },
              },
            },
            formatter = {},
          },
          {
            includes = {
              'assets/**/*.js',
              'public/**/*.js',
              '**/app.js',
            },
            javascript = {
              linter = {
                enabled = true,
                rules = {
                  style = {
                    noInferrableTypes = 'off',
                  },
                  correctness = {
                    noUnusedVariables = 'error',
                    noUnusedImports = 'error',
                  },
                },
              },
            },
          },
        },
        css = {
          linter = {
            enabled = true,
          },
          formatter = {
            enabled = true,
            indentStyle = 'space',
            indentWidth = 2,
          },
        },
        javascript = {
          formatter = {
            jsxQuoteStyle = 'double',
            quoteProperties = 'asNeeded',
            trailingCommas = 'all',
            semicolons = 'always',
            arrowParentheses = 'always',
            bracketSpacing = true,
            bracketSameLine = false,
            quoteStyle = 'single',
            attributePosition = 'auto',
          },
        },
        html = {
          formatter = {
            enabled = true,
          },
        },
        json = {
          parser = {
            allowComments = false,
            allowTrailingCommas = false,
          },
          linter = {
            enabled = true,
            rules = {
              style = {
                useConst = 'error',
                useSingleVarDeclarator = 'error',
              },
              correctness = {
                noUnusedVariables = 'error',
                noUnusedImports = 'error',
              },
            },
          },
          formatter = {
            enabled = true,
            indentStyle = 'space',
            indentWidth = 2,
          },
        },
        vcs = {
          clientKind = 'git',
          enabled = false,
          useIgnoreFile = false,
        },
      },
    },
  },
  workspace_required = false,
  before_init = function(_, config)
    local bufnr = vim.api.nvim_get_current_buf()
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == '' then
      return
    end

    local deno_root = vim.fs.root(fname, {
      'deno.json',
      'deno.jsonc',
      'deno.lock',
    })
    if deno_root then
      return
    end

    local project_root = vim.fs.root(fname, {
      'biome.json',
      'biome.jsonc',
      'package-lock.json',
      'yarn.lock',
      'pnpm-lock.yaml',
      'bun.lockb',
      'bun.lock',
      '.git',
    }) or vim.fn.getcwd()

    local local_cmd = project_root .. '/node_modules/.bin/biome'
    if vim.fn.executable(local_cmd) == 1 then
      config.cmd = { local_cmd, 'lsp-proxy' }
    end
  end,
}
