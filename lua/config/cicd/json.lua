-- qompassai/Diver/lua/config/cicd/build.lua
-- Qompass AI Diver CICD JSON Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.json_autocmds()
  local augroups = {
    json = vim.api.nvim_create_augroup('JSON', {
      clear = true,
    }),
  }
  vim.api.nvim_create_autocmd({
    'TextChanged',
    'InsertLeave',
  }, {
    group = augroups.json,
    pattern = { '*.json', '*.jsonc', '*.json5' },
    callback = function()
      vim.diagnostic.reset()
      if vim.lsp.buf.document_highlight then
        vim.lsp.buf.document_highlight()
      end
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
        if client:supports_method('textDocument/semanticTokens') then
          pcall(vim.lsp.buf.semantic_tokens_refresh)
          break
        end
      end
    end,
  })
end

function M.json_cmp(opts)
  local sources = opts.sources or {}
  local has_json_source = vim.tbl_contains(
    vim.tbl_map(function(s)
      return s.name == 'json'
    end, sources),
    true
  )
  if not has_json_source then
    table.insert(sources, {
      name = 'lsp',
      group_index = 1,
      priority = 100,
      filetypes = { 'json', 'jsonc', 'json5', 'jsonl' },
      entry_filter = function(ctx)
        local ft = vim.bo[ctx.bufnr].filetype ---@type table
        return vim.tbl_contains({ 'json', 'jsonc', 'json5', 'jsonl' }, ft)
      end,
    })
  end
  opts.sources = sources ---@type table
  return opts
end

function M.json_filetype_detection()
  vim.filetype.add({
    extension = {
      json = 'json',
      jsonc = 'jsonc',
      json5 = 'json5',
      jsonl = 'jsonl',
    },
    pattern = {
      ['%.json5$'] = 'json5',
      ['%.jsonl$'] = 'jsonl',
      ['%.jsonc$'] = 'jsonc',
      ['tsconfig.*%.json'] = 'jsonc',
      ['.*rc%.json'] = 'jsonc',
    },
    filename = {
      ['.eslintrc.json'] = 'jsonc',
      ['.babelrc'] = 'jsonc',
      ['.prettierrc'] = 'jsonc',
      ['tsconfig.json'] = 'jsonc',
      ['package.json'] = 'json',
    },
  })
end

return M