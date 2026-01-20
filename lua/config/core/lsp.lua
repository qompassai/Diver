-- /qompassai/Diver/lsp/lsp.lua
-- Qompass AI Diver Native LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
function M.on_attach(client, bufnr)
  if client.server_capabilities.completionProvider then
    vim.lsp.completion.enable(true, client.id, bufnr, {
      autotrigger = true,
      convert = function(item)
        return {
          abbr = item.label:gsub('%b()', ''),
        }
      end,
    })
  end
  if client.server_capabilities.inlineCompletionProvider then
    vim.lsp.inline_completion.enable(true, {
      bufnr = bufnr,
      client_id = client.id,
      autotrigger = true,
    })
  end
  if client.server_capabilities.documentHighlightProvider then
    vim.api.nvim_create_autocmd({
      'CursorHold',
      'CursorHoldI',
    }, {
      buffer = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({
      'CursorMoved',
      'CursorMovedI',
      'BufLeave',
    }, {
      buffer = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end
  if client:supports_method('textDocument/inlayHint') and vim.lsp.inlay_hint then
    vim.lsp.inlay_hint.enable(true, {
      bufnr = bufnr,
    })
  end
  if client.server_capabilities.semanticTokensProvider then
    vim.lsp.semantic_tokens.enable(true, {
      bufnr = bufnr,
    })
  end
  if
      client.server_capabilities.documentFormattingProvider
      or client.server_capabilities.documentRangeFormattingProvider
  then
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function(args)
        vim.lsp.buf.format({
          async = true,
          bufnr = args.buf,
        })
      end,
    })
  end
  vim.api.nvim_create_autocmd('LspDetach', {
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if not client_id then
        return
      end
      local detached_client = vim.lsp.get_client_by_id(client_id)
      if not detached_client then
        return
      end
      if detached_client:supports_method('textDocument/formatting') then
        vim.api.nvim_clear_autocmds({
          group = vim.api.nvim_create_augroup('LspFormatOnSave', { clear = false }),
          buffer = args.buf,
        })
      end
    end,
  })
end

vim.cmd('runtime! lsp/init.lua')
vim.diagnostic.config({
  float = {
    border = 'rounded',
    source = true,
    focusable = true,
    scope = 'line',
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
  },
  severity_sort = true,
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
  underline = {
    severity = {
      min = vim.diagnostic.severity.HINT,
      max = vim.diagnostic.severity.ERROR,
    },
  },
  update_in_insert = true,
  virtual_lines = {
    only_current_line = false,
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
  },
  virtual_text = {
    enabled = true,
    source = true,
    spacing = 4,
    severity = {
      min = vim.diagnostic.severity.WARN,
    },
    prefix = function(diag, i, total)
      ---@cast diag vim.Diagnostic
      local icons = {
        [vim.diagnostic.severity.ERROR] = ' ',
        [vim.diagnostic.severity.WARN] = ' ',
        [vim.diagnostic.severity.INFO] = ' ',
        [vim.diagnostic.severity.HINT] = ' ',
      }
      return string.format('%s%d/%d ', icons[diag.severity] or ' ', i, total)
    end,
  },
})
vim.diagnostic.enable(true)
M.capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
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
          'plaintext',
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
      symbolKind = {},
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
    publishDiagnostics = {
      dynamicRegistration = true,
      relatedInformation = true,
    },
    rename = {
      dynamicRegistration = true,
      prepareSupport = true,
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
    },
    signatureHelp = {
      dynamicRegistration = true,
      signatureInformation = {
        documentationFormat = {
          'markdown',
          'plaintext',
        },
        parameterInformation = {
          labelOffsetSupport = true,
        },
      },
    },
    synchronization = {
      dynamicRegistration = true,
      willSave = true,
      willSaveWaitUntil = true,
      didSave = true,
      syncKind = vim.lsp.protocol.TextDocumentSyncKind.Incremental,
    },
  },
})
vim.lsp.config( ---@type vim.lsp.Config
  '*',
  {
    autostart = true,
    on_attach = M.on_attach,
    capabilities = M.capabilities,
    workspace_required = false,
  }
)
vim.api.nvim_create_autocmd('LspAttach', {
  ---@param ev { buf: integer, data: { client_id: integer } }
  callback = function(ev)
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
  end,
})
vim.api.nvim_create_autocmd('User', {
  pattern = 'LspSemanticTokens',
  callback = function(args)
    if not args.data or not args.data.client_id or not args.data.token then
      return
    end
    local token = args.data.token
    vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, 'MyMutableVariableHighlight')
  end,
})
vim.lsp.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, _)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end
  vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
end
vim.api.nvim_create_autocmd('LspProgress', {
  callback = function(ev)
    local value = ev.data.params.value ---@type table
    if value.kind == 'begin' then
      vim.api.nvim_ui_send('\027]9;4;1;0\027\\')
    elseif value.kind == 'end' then
      vim.api.nvim_ui_send('\027]9;4;0\027\\')
    elseif value.kind == 'report' then
      vim.api.nvim_ui_send(string.format('\027]9;4;1;%d\027\\', value.percentage or 0))
    end
  end,
})
vim.api.nvim_create_autocmd('LspTokenUpdate', {
  callback = function(args)
    local token = args.data.token ---@type table
    if token.type == 'variable' and not token.modifiers.readonly then
      vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, 'MyMutableVariableHighlight')
    end
  end,
})
return M