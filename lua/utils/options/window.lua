-- /qompassai/Diver/lua/utils/options/window.lua
-- Qompass AI Diver Window Options
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- Every window-local Neovim option, set explicitly and alphabetically.
---
--- Plain-language version: this file lists every win Neovim option
--- alphabetically and sets each one on purpose, so the whole win
--- configuration is visible in one place instead of hiding in defaults.
---@module 'utils.options.window'

local wo = vim.wo

-- Not set here (global-local, not customized by init.lua: no local
-- value is written, so the global default -- possibly set by a plugin
-- after startup -- stays visible):
--   fillchars, listchars, scrolloffpad, statusline, winbar

local M = {}

--- Apply every win-scoped option. Idempotent.
--- Values marked (custom) are Matt's explicit choices; the rest are
--- Neovim's own defaults, written out so nothing is implicit.
function M.setup()
    wo.arabic = false
    wo.breakindent = true -- custom
    wo.breakindentopt = 'shift:2,sbr' -- custom
    wo.colorcolumn = ''
    wo.concealcursor = 'nc' -- custom
    wo.conceallevel = 0 -- custom
    wo.cursorbind = false -- custom
    wo.cursorcolumn = false
    wo.cursorline = true -- custom
    wo.cursorlineopt = 'both' -- custom
    wo.diff = false
    wo.eventignorewin = ''
    wo.foldcolumn = '1' -- custom
    wo.foldenable = false -- custom
    wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()' -- custom
    wo.foldignore = '#'
    wo.foldlevel = 99 -- custom
    wo.foldmarker = '{{{,}}}'
    wo.foldmethod = 'expr' -- custom
    wo.foldminlines = 1
    wo.foldnestmax = 20
    wo.foldtext = 'foldtext()'
    wo.lhistory = 10
    wo.linebreak = true -- custom
    wo.list = true -- custom
    wo.number = true -- custom
    wo.numberwidth = 4
    wo.previewwindow = false
    wo.relativenumber = true -- custom
    wo.rightleft = false
    wo.rightleftcmd = 'search'
    wo.scroll = 0
    wo.scrollbind = false
    wo.scrolloff = 20 -- custom
    wo.showbreak = '↪' -- custom
    wo.sidescrolloff = 20 -- custom
    wo.signcolumn = 'yes:1' -- always show, prevents layout shift
    wo.smoothscroll = true -- custom
    wo.spell = true -- custom
    wo.statuscolumn = ''
    wo.virtualedit = 'block' -- custom
    wo.winblend = 40 -- custom
    wo.winfixbuf = false
    wo.winfixheight = false
    wo.winfixwidth = false
    wo.winhighlight = ''
    wo.winpinned = false
    wo.wrap = true -- custom
end

return M
