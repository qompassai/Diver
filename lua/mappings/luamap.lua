-- ~/.config/nvim/lua/mappings/luamap.lua
local M = {}

function M.setup_luamap()
  local map = vim.keymap.set
  local cmp = require('cmp')
  local luasnip = require('luasnip')

  map('i', '<C-d>', cmp.mapping.scroll_docs(-4), { desc = "Scroll docs up" })
  map('i', '<C-f>', cmp.mapping.scroll_docs(4), { desc = "Scroll docs down" })
  map('i', '<C-Space>', cmp.mapping.complete, { desc = "Open completion" })
  
  map('i', '<CR>', function()
    if cmp.visible() then
      cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 'n', true)
    end
  end, { desc = "Confirm selection" })

  map('i', '<Tab>', function()
    if cmp.visible() then
      cmp.select_next_item()
    elseif luasnip.expand_or_jumpable() then
      luasnip.expand_or_jump()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, true, true), 'n', true)
    end
  end, { desc = "Next item or expand snippet" })

  map('i', '<S-Tab>', function()
    if cmp.visible() then
      cmp.select_prev_item()
    elseif luasnip.jumpable(-1) then
      luasnip.jump(-1)
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<S-Tab>', true, true, true), 'n', true)
    end
  end, { desc = "Previous item or jump snippet" })
end

return M

