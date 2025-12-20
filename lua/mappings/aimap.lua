-- /qompassai/Diver/lua/mappings/aimap.lua
-- Qompass AI Diver AI Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.aimap'
local M = {}
function M.setup_aimap() ---@type function
  local map = vim.keymap.set ---@type string
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local opts = { noremap = true, silent = true, buffer = bufnr }

      -- Rose Open a new chat
      map('n', '<C-g>c', ':RoseChatNew<CR>', vim.tbl_extend('force', opts, { desc = '[r]ose [c]hat' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'c' to open a new chat.

      -- Rose Toggle Popup Chat
      map('n', '<C-g>t', ':RoseChatToggle<CR>', vim.tbl_extend('force', opts, { desc = '[r] Toggle Popup Chat' }))
      -- In normal mode, press 'Ctrl' + 'g' + 't' to toggle the popup chat.

      -- Rose Chat Finder
      map('n', '<C-g>f', ':RoseChatFinder<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Chat Finder' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'f' to open the chat finder.

      -- Rose Trigger the API to generate a response
      map('n', '<C-g><C-g>', ':RoseChatRespond<CR>', opts)
      -- In normal mode, press 'Ctrl' + 'g' + 'g' to trigger the API to generate a response.

      -- Rose Stop the current text generation
      map('n', '<C-g>s', ':RoseStop<CR>', opts)
      -- In normal mode, press 'Ctrl' + 'g' + 's' to stop the current text generation.

      -- Rose Delete the current chat file
      map('n', '<C-g>d', ':RoseChatDelete<CR>', opts)
      -- In normal mode, press 'Ctrl' + 'g' + 'd' to delete the current chat file.

      -- Rose Select Provider
      map('n', '<C-g>p', '<cmd>RoseProvider<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Select provider' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'p' to select a provider.

      -- Rose Switch Model
      map('n', '<C-g>m', ':RoseModel<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Switch model' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'm' to switch the model.

      -- Rose Print plugin config
      map('n', '<C-g>i', ':RoseInfo<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Print plugin config' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'i' to print the plugin config.

      -- Rose Edit local context file
      map('n', '<C-g>e', ':RoseContext<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Edit local context file' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'e' to edit the local context file.

      -- Rose Rewrites the visual selection
      map('v', '<C-g>r', ':RoseRewrite<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Rewrite selection' }))
      -- In visual mode, press 'Ctrl' + 'g' + 'r' to rewrite the visual selection based on a prompt.

      -- Rose Append text to selection
      map('v', '<C-g>a', ':RoseAppend<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Append to selection' }))
      -- In visual mode, press 'Ctrl' + 'g' + 'a' to append text to the visual selection.

      -- Rose Prepend text to selection
      map('v', '<C-g>p', ':RosePrepend<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Prepend to selection' }))
      -- In visual mode, press 'Ctrl' + 'g' + 'p' to prepend text to the visual selection.

      -- Rose Repeat last action
      map('n', '<C-g>r', ':RoseRetry<CR>', vim.tbl_extend('force', opts, { desc = 'Rose Repeat last action' }))
      -- In normal mode, press 'Ctrl' + 'g' + 'r' to repeat the last rewrite/append/prepend.
    end
  })
end

return M