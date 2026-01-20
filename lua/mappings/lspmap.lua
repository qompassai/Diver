-- /qompassai/Diver/lua/mappings/lspmap.lua
-- Qompass AI Diver Language Server Protocol (LSP) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.lspmap'
---LSP keymap module.
local M = {} ---@class mappings.lspmap
---@alias LspAttachArgs { buf: integer, data: { client_id: integer } }
function M.setup_lspmap() ---@return nil
  local function on_list(options) ---@param options table
    vim.fn.setqflist({}, ' ', options)
    vim.cmd.cfirst()
  end
  function M.on_attach(args) ---@param args LspAttachArgs
    local bufnr = args.buf ---@type integer
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local clients = vim.lsp.get_clients( ---@type vim.lsp.Client[]
      {
        bufnr = bufnr,
      }
    )
    local map = vim.keymap.set
    local opts = {
      buffer = bufnr,
      silent = true,
    }
    map('n', 'gd', function()
      for _, c in ipairs(clients) do
        if c:supports_method('textDocument/definition') then
          vim.lsp.buf.definition({
            loclist = true,
          })
          return
        end
      end
      vim.echo('No LSP supports textDocument/definition for this buffer', vim.log.levels.WARN)
    end, {
      silent = true,
      buffer = bufnr,
    })
    map('n', '<leader>lc', vim.lsp.buf.document_color, {
      buffer = bufnr,
      silent = true,
      desc = 'LSP document color',
    })
    map(
      'n',
      'K',
      vim.lsp.buf.hover,
      vim.tbl_extend('force', opts, {
        desc = 'Show hover information',
      })
    )
    map('n', 'gI', vim.lsp.buf.implementation, opts)
    map(
      'n',
      'g0',
      vim.lsp.buf.document_symbol,
      vim.tbl_extend('force', opts, {
        desc = 'Show document symbols',
      })
    )
    map('n', 'g0', vim.lsp.buf.document_symbol, opts)
    map(
      'n',
      'gW',
      vim.lsp.buf.workspace_symbol,
      vim.tbl_extend('force', opts, {
        desc = 'Show workspace symbols',
      })
    )
    map(
      'n',
      '<leader>rn',
      vim.lsp.buf.rename,
      vim.tbl_extend('force', opts, {
        desc = 'Rename symbol',
      })
    )
    map(
      'n',
      'ga',
      vim.lsp.buf.code_action,
      vim.tbl_extend('force', opts, {
        desc = 'Code actions',
      })
    )
    map(
      'n',
      '<leader>f',
      function()
        vim.lsp.buf.format({
          async = true,
          bufnr = bufnr,
        })
      end,
      vim.tbl_extend('force', opts, {
        desc = 'Format buffer',
      })
    )
    map(
      'n',
      '[d',
      function()
        vim.diagnostic.jump({
          count = -1,
        })
      end,
      vim.tbl_extend('force', opts, {
        desc = 'Previous diagnostic',
      })
    )
    map(
      'n',
      ']d',
      function()
        vim.diagnostic.jump({
          count = 1,
        })
      end,
      vim.tbl_extend('force', opts, {
        desc = 'Next diagnostic',
      })
    )
    map(
      'n',
      '<leader>fD',
      function()
        vim.diagnostic.open_float(nil, {
          scope = 'line',
        })
      end,
      vim.tbl_extend('force', opts, {
        desc = 'Show line diagnostics',
      })
    )
    map('n', '<leader>li', vim.cmd.LspInfo, {
      buffer = bufnr,
      silent = true,
      desc = 'Show LSP info',
    })
    if client and client:supports_method('textDocument/signatureHelp') then
      map(
        'i',
        '<C-k>',
        vim.lsp.buf.signature_help,
        vim.tbl_extend('force', opts, {
          desc = 'Show signature help',
        })
      )
    end
    map('i', '<c-space>', function()
      vim.lsp.completion.get()
    end, {
      buffer = bufnr,
      desc = 'Trigger LSP completion',
    })
    map('i', '<Tab>', function()
      if not vim.lsp.inline_completion.get() then
        return '<Tab>'
      end
    end, {
      expr = true,
      desc = 'Accept the current inline completion',
    })
    if vim.bo[bufnr].filetype == 'typescript' or vim.bo[bufnr].filetype == 'typescriptreact' then
      map('n', '<leader>ct', '<Nop>', {
        buffer = bufnr,
        silent = true,
        desc = '+TypeScript',
      })
      map(
        'n',
        '<leader>cta',
        vim.lsp.buf.code_action,
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript code actions',
        })
      )
      map(
        'n',
        '<leader>ctr',
        vim.lsp.buf.rename,
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript rename symbol',
        })
      )
      map(
        'n',
        '<leader>cti',
        '<cmd>TypescriptOrganizeImports<cr>',
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript organize imports',
        })
      )
      map(
        'n',
        '<leader>ctd',
        '<cmd>TypescriptGoToSourceDefinition<cr>',
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript go to source definition',
        })
      )
      map(
        'n',
        '<leader>ctt',
        '<cmd>TypescriptAddMissingImports<cr>',
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript add missing imports',
        })
      )
      map(
        'n',
        '<leader>cts',
        '<cmd>lua require(\'telescope.builtin\').lsp_document_symbols()<cr>',
        vim.tbl_extend('force', opts, {
          desc = 'TypeScript document symbols (Telescope)',
        })
      )
    end
  end
end

return M
--]]
--[[local registry = require('mason-registry')

function M.setup_masonmap()
    ---@return table<string, string[]>
    function M.get_language_map()
        if not registry.get_all_package_specs then
            return {}
        end
        ---@type table<string, string[]>
        local languages = {}
        for _, pkg_spec in ipairs(registry.get_all_package_specs()) do
            for _, language in ipairs(pkg_spec.languages) do
                language = language:lower()
                if not languages[language] then
                    languages[language] = {}
                end
                table.insert(languages[language], pkg_spec.name)
            end
        end
        return languages
    end
end
--]]