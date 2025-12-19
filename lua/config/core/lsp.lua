-- /qompassai/Diver/lsp/lsp.lua
-- Qompass AI Diver Native LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta
---@module 'config.core.lsp'
local function on_list(options) ---@param options table
  vim.fn.setqflist({}, ' ', options)
  vim.cmd.cfirst()
end
local lspmap = require('mappings.lspmap') ---@type mappings.lspmap
vim.api.nvim_create_autocmd('LspAttach', {
  callback = lspmap.on_attach,
})
vim.api.nvim_create_autocmd({
  'BufEnter',
  'CursorHold',
  'InsertLeave',
}, {
  callback = function()
    vim.lsp.codelens.refresh()
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client:supports_method('textDocument/foldingRange') then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
    end
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    vim.diagnostic.show(vim.api.nvim_create_namespace('my_diagnostics'), ev.buf, nil, {
      virtual_text = {
        spacing = 2,
        source = 'if_many',
        severity = {
          min = vim.diagnostic.severity.WARN,
        },
        prefix = function(diag, i, total) ---@param diag vim.Diagnostic
          local icons = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.INFO] = ' ',
            [vim.diagnostic.severity.HINT] = ' ',
          }
          return string.format('%s%d/%d ', icons[diag.severity], i, total)
        end,
      },
      signs = true,
      severity_sort = true,
      virtual_lines = true,

      underline = true,
    })
  end,
})
vim.cmd('runtime! lsp/init.lua')
capabilities = vim.lsp.protocol.make_client_capabilities()
vim.diagnostic.handlers.loclist = {
  show = function(_, _, _, opts)
    opts.loclist.open = opts.loclist.open or false
    local winid = vim.api.nvim_get_current_win()
    vim.diagnostic.setloclist(opts.loclist)
    vim.api.nvim_set_current_win(winid)
  end,
}
vim.diagnostic.config({
  float = {
    border = 'rounded',
    source = 'if_many',
    focusable = true,
    scope = 'line',
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
    severity_sort = true,
    update_in_insert = true,
  },
  virtual_text = {
    enabled = true,
    prefix = '●',
    spacing = 4,
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
  },
  virtual_lines = {
    only_current_line = false,
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
  },
  underline = {
    severity = {
      min = vim.diagnostic.severity.HINT,
      max = vim.diagnostic.severity.ERROR,
    },
  },
  signs = {
    linehl = {
      [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
      [vim.diagnostic.severity.WARN] = 'WarningMsg',
      [vim.diagnostic.severity.INFO] = 'DiagnosticInfo',
      [vim.diagnostic.severity.HINT] = 'DiagnosticHint',
    },
    numhl = {
      [vim.diagnostic.severity.ERROR] = 'DiagnosticError',
      [vim.diagnostic.severity.WARN] = 'DiagnosticWarn',
      [vim.diagnostic.severity.INFO] = 'DiagnosticInfo',
      [vim.diagnostic.severity.HINT] = 'DiagnosticHint',
    },
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  },
  status = {
    text = {
      [vim.diagnostic.severity.ERROR] = 'E',
      [vim.diagnostic.severity.WARN]  = 'W',
      [vim.diagnostic.severity.INFO]  = 'I',
      [vim.diagnostic.severity.HINT]  = 'H',
    },
  },
})
vim.diagnostic.enable()
vim.lsp.buf.references(nil, {
  on_list = on_list,
  loclist = true,
})
vim.lsp.buf.definition({
  loclist = true
})
vim.lsp.config( ---@type vim.lsp.Config
  '*',
  {
    autostart = true,
    capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
      completion = {
        dynamicRegistration = true,
        completionItem = {
          snippetSupport = true,
          commitCharactersSupport = true,
          deprecatedSupport = true,
          labelDetailsSupport = true,
          preselectSupport = true,
          insertReplaceSupport = true,
          documentationFormat = {
            'markdown',
            'plaintext',
          },
          resolveSupport = {
            properties = {
              'additionalTextEdits',
              'documentation',
              'detail',
            },
          },
        },
      },
      flags = {
        debounce_text_changes = 150,
        exit_timeout = 500,
      },
      single_file_support = true,
      textDocument = {
        codeAction = {
          dynamicRegistration = true,
          codeActionLiteralSupport = {
            codeActionKind = {
              valueSet = {
                'quickfix',
                'refactor',
                'refactor.extract',
                'refactor.inline',
                'refactor.rewrite',
                'source',
                'source.organizeImports',
              },
            },
          },
        },
        codelens = {
          dynamicRegistration = true,
        },
        completion = {
          dynamicRegistration = true,
          completionItem = {
            snippetSupport = true,
            commitCharactersSupport = true,
            deprecatedSupport = true,
            preselectSupport = true,
            insertReplaceSupport = true,
            labelDetailsSupport = true,
            documentationFormat = {
              'markdown',
              'plaintext'
            },
            resolveSupport = {
              properties = {
                'documentation',
                'detail',
                'additionalTextEdits',
              },
            },
          },
          contextSupport = true,
        },
        diagnostic = {},
        documentHighlight = {
          dynamicRegistration = true,
        },
        documentSymbol = {
          dynamicRegistration = true,
          hierarchicalDocumentSymbolSupport = true,
          symbolKind = {
            valueSet = vim.tbl_range(1, 26),
          },
        },
        formatting = {
          dynamicRegistration = true,
        },
        hover = {
          dynamicRegistration = true,
          contentFormat = {
            'markdown',
            'plaintext',
          },
        },
        inlayHint = {
          dynamicRegistration = true,
        },
        inlineCompletion = {
          dynamicRegistration = true,
        },
        publishDiagnotics = {
          dynamicRegistration = true,
        },
        rename = {
          dynamicRegistration = true,
          prepareSupport = true,
        },
        publishDiagnostics = {
          relatedInformation = true,
        },
        semanticTokens = {
          multilineTokenSupport = true,
          requests = {
            range = true,
            full = {
              delta = true,
            },
          },
          tokenTypes = {
            'class',
            'comment',
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
            'string',
            'struct',
            'type',
            'typeParameter',
            'variable',
          },
          tokenModifiers = {
            'abstract',
            'async',
            'declaration',
            'defaultLibrary',
            'definition',
            'deprecated',
            'documentation',
            'modification',
            'readonly',
            'static',
          },
          signatureHelp = {
            dynamicRegistration = true,
            signatureInformation = {
              documentationFormat = {
                'markdown',
                'plaintext'
              },
              parameterInformation = {
                labelOffsetSupport = true
              },
            },
          },
          synchronization = {
            dynamicRegistration = true,
            willSave = false,
            willSaveWaitUntil = true,
            didSave = true,
            syncKind = vim.lsp.protocol.TextDocumentSyncKind.Incremental,
          },
        },
      },
    }),
    workspace_required = false,
  }
)
vim.lsp.document_color.enable()
vim.lsp.inline_completion.enable()
vim.lsp.on_type_formatting.enable()
vim.lsp.semantic_tokens.enable()