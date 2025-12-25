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
        bufnr = bufnr
      })
    local map = vim.keymap.set
    local opts = {
      buffer = bufnr,
      silent = true
    }
    -- Go to definition with loclist population *if* supported
    map('n', 'gd', function()
      for _, c in ipairs(clients) do
        if c:supports_method('textDocument/definition') then
          vim.lsp.buf.definition({
            loclist = true
          })
          return
        end
      end
      vim.echo('No LSP supports textDocument/definition for this buffer',
        vim.log.levels.WARN)
    end, {
      silent = true,
      buffer = bufnr
    })
    map('n', 'gr', function()
      vim.lsp.buf.references(nil,
        {
          on_list = on_list
        })
    end, opts)
    map('n', 'K',
      vim.lsp.buf.hover, opts)
    map('n', 'gI',
      vim.lsp.buf.implementation, opts)
    map('n', 'g0',
      vim.lsp.buf.document_symbol, opts)
    map('n', 'gW',
      vim.lsp.buf.workspace_symbol, opts)
    map('n', '<leader>rn',
      vim.lsp.buf.rename, opts)
    map('n', 'ga',
      vim.lsp.buf.code_action, opts)
    map('n', '<leader>f',
      function()
        vim.lsp.buf.format(
          {
            async = true,
            bufnr = bufnr
          })
      end, opts)
    map('n', '[d', function()
      vim.diagnostic.jump({ count = -1 })
    end, opts)
    map('n', ']d', function()
      vim.diagnostic.jump({ count = 1 })
    end, opts)
    map('n', '<leader>fD',
      function()
        vim.diagnostic.open_float(nil,
          {
            scope = 'line'
          })
      end, opts)
    map('n', '<leader>li',
      vim.cmd.LspInfo,
      {
        buffer = bufnr,
        silent = true
      })
    if client and client:supports_method('textDocument/signatureHelp') then
      map('i', '<C-k>',
        vim.lsp.buf.signature_help, opts)
    end
    if client and client:supports_method('textDocument/inlayHint')
        and vim.lsp.inlay_hint
    then
      vim.lsp.inlay_hint.enable(true,
        {
          bufnr = bufnr
        })
    end
    if client and client:supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre',
        {
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({
              bufnr = bufnr,
              async = true
            })
          end,
        })
    end
    map('i', '<c-space>', function()
      vim.lsp.completion.get()
    end)

    map('i', '<Tab>', function()
      if not vim.lsp.inline_completion.get() then
        return '<Tab>'
      end
    end, {
      expr = true,
      desc = 'Accept the current inline completion',
    })
    vim.api.nvim_create_autocmd('LspAttach',
      {
        ---@param ev LspAttachArgs
        callback = function(ev)
          vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end,
      })
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