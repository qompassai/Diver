-- /qompassai/Diver/lua/config/core/whichkey.lua
-- Qompass AI Diver WhichKey Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'config.core.whichkey'
local WK = {}
WK.opts = {
  debug = false,
  defer = function(ctx)
    return ctx.mode == 'V' or ctx.mode == '<C-V>'
  end,
  expand = 0,
  icons = {
    breadcrumb = '»',
    ellipsis = '…',
    group = '+',
    mappings = true,
    separator = '➜',
    colors = true,
    keys = {
      BS = '󰁮',
      CR = '󰌑 ',
      Down = ' ',
      Esc = '󱊷 ',
      F1 = '󱊫',
      F10 = '󱊴',
      F11 = '󱊵',
      F12 = '󱊶',
      F2 = '󱊬',
      F3 = '󱊭',
      F4 = '󱊮',
      F5 = '󱊯',
      F6 = '󱊰',
      F7 = '󱊱',
      F8 = '󱊲',
      F9 = '󱊳',
      Left = ' ',
      Right = ' ',
      Up = ' ',
      Space = '󱁐 ',
      Tab = '󰌒 ',
      C = '󰘴 ',
      D = '󰘳 ',
      M = '󰘵 ',
      S = '󰘶 ',
    },
    rules = {},
  },
  layout = {
    spacing = 3,
    width = {
      min = 20
    },
  },
  notify = true,
  plugins = {
    marks = true,
    presets = {
      g = true,
      motions = true,
      nav = true,
      operators = true,
      text_objects = true,
      windows = true,
      z = true,
    },
    registers = true,
    spelling = { enabled = true, suggestions = 20 },
  },
  preset = 'modern',
  replace = {
    desc = {
      { '^:%s*',            '' },
      { '^%+',              '' },
      { '<Plug>%(?(.*)%)?', '%1' },
      { '<[cC]md>',         '' },
      { '<[cC][rR]>',       '' },
      { '<[sS]ilent>',      '' },
      { '^call%s+',         '' },
      { '^lua%s+',          '' },
    },
    key = {
      function(key)
        return require('which-key.view').format(key)
      end,
    },
  },
  show_help = true,
  show_keys = true,
  sort = {
    'local',
    'order',
    'group',
    'alphanum',
    'mod'
  },
  spec = {},
  triggers = {
    { '<auto>', mode = 'nixsotc' },
    { 'a',      mode = { 'n', 'v' } },
  },
  win = {
    no_overlap = true,
    padding = {
      1,
      2
    },
    title = true,
    title_pos = 'center',
    zindex = 1000,
  },
}
function WK.setup(extra)
  require('which-key').setup(vim.tbl_deep_extend('force', WK.opts, extra or {}))
  vim.keymap.set('n', '<leader>?', function()
    require('which-key').show({ global = false })
  end, { desc = 'Buffer Local Keymaps (which-key)' })
end

return WK