#!/usr/bin/env lua

-- buffer.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- lua/utils/options/buffer.lua
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn
bo.autocomplete = true
bo.autoindent = true
bo.autoread = true
bo.backupcopy = 'auto'
bo.busy = 1
bo.completeopt = 'menu,menuone,noselect'
bo.expandtab = true
bo.fileencoding = 'utf-8'
bo.grepprg = 'rg --vimgrep'
bo.iminsert = 0
bo.imsearch = -1
bo.lisp = true
bo.lispwords = 'defgeneric,block,catch'
bo.modeline = true
bo.modifiable = true
bo.nrformats = 'hex'
bo.shiftwidth = 4
bo.smartindent = true
bo.spellfile = fn.stdpath('config') .. '/spell/en.utf-8.add'
bo.spelllang = 'en_us'
bo.spelloptions = 'camel'
bo.swapfile = false
bo.softtabstop = 2
bo.tabstop = 2
bo.textwidth = 120
bo.undofile = true
cmd('filetype plugin on')
cmd('filetype plugin indent on')
