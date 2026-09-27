-- /qompassai/Diver/lua/utils/options/buffer.lua
-- Qompass AI Diver Buffer Options
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- Every buffer-local Neovim option, set explicitly and alphabetically.
---
--- Plain-language version: this file lists every buf Neovim option
--- alphabetically and sets each one on purpose, so the whole buf
--- configuration is visible in one place instead of hiding in defaults.
---@module 'utils.options.buffer'

-- Buffer-local options write to the *current* buffer. On startups where the
-- plugin manager installed or built plugins, that buffer can be the
-- manager's own nomodifiable UI buffer, and writing makes Neovim abort
-- with E21 -- which skips the rest of init.lua. So everything below runs
-- only on a modifiable buffer. (Non-modifiable plugin UI buffers keep
-- their own local values; file buffers get these when opened.)

-- Not set here (global-local, not customized by init.lua: no local
-- value is written, so the global default -- possibly set by a plugin
-- after startup -- stays visible):
--   define, dictionary, diffanchors, equalprg, errorformat, findfunc,
--   formatprg, fsync, grepformat, include, keywordprg, makeencoding,
--   makeprg, path, tagcase, thesaurus, thesaurusfunc, undolevels

local M = {}

--- Apply every buf-scoped option. Idempotent.
--- Values marked (custom) are Matt's explicit choices; the rest are
--- Neovim's own defaults, written out so nothing is implicit.
function M.setup()
    -- See the E21 note at the top of this file.
    if vim.bo.modifiable then
        local bo = vim.bo
        bo.autocomplete = false -- custom
        bo.autoindent = true -- custom
        bo.autoread = true -- custom
        bo.backupcopy = 'auto' -- custom
        bo.binary = false
        bo.bomb = false
        bo.bufhidden = ''
        bo.buflisted = true
        bo.buftype = ''
        bo.busy = 1 -- custom
        bo.cindent = false
        bo.cinkeys = '0{,0},0),0],:,0#,!^F,o,O,e'
        bo.cinoptions = ''
        bo.cinscopedecls = 'public,protected,private'
        bo.cinwords = 'if,else,while,do,for,switch'
        bo.comments = 's1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-,fb:•' -- custom
        bo.commentstring = ''
        bo.complete = '.^20,w^10,b^10' -- custom
        bo.completefunc = ''
        bo.completeopt = 'menu,menuone,noselect,fuzzy' -- custom
        bo.completeslash = ''
        bo.copyindent = false
        bo.endoffile = false
        bo.endofline = true
        bo.expandtab = true -- custom
        bo.fileencoding = 'utf-8' -- custom
        bo.fileformat = 'unix'
        bo.fixendofline = true
        bo.formatexpr = ''
        bo.formatlistpat = '^\\s*\\d\\+[\\]:.)}\\t ]\\s*'
        bo.formatoptions = 'tcqj' -- custom
        bo.grepprg = 'rg --vimgrep' -- custom
        bo.iminsert = 0 -- custom
        bo.imsearch = -1 -- custom
        bo.includeexpr = ''
        bo.indentexpr = ''
        bo.indentkeys = '0{,0},0),0],:,0#,!^F,o,O,e'
        bo.infercase = false
        bo.iskeyword = '@,48-57,_,192-255'
        bo.keymap = ''
        bo.lisp = true -- custom
        bo.lispoptions = ''
        bo.lispwords = 'defgeneric,block,catch' -- custom
        bo.matchpairs = '(:),{:},[:]'
        bo.modeline = true -- custom
        bo.modifiable = true -- custom
        bo.modified = false
        bo.nrformats = 'hex' -- custom
        bo.omnifunc = ''
        bo.preserveindent = false
        bo.quoteescape = '\\'
        bo.readonly = false -- custom
        bo.scrollback = -1
        bo.shiftwidth = 4 -- custom
        bo.smartindent = true -- custom
        bo.softtabstop = 2 -- custom
        bo.spellcapcheck = '[.?!]\\_[\\])\'"\\t ]\\+'
        bo.spellfile = vim.fn.stdpath('config') .. '/spell/en.utf-8.add' -- custom
        bo.spelllang = 'en_us' -- custom
        bo.spelloptions = 'camel' -- custom
        bo.suffixesadd = ''
        bo.swapfile = false -- custom
        bo.synmaxcol = 3000
        bo.tabstop = 2 -- custom
        bo.tagfunc = ''
        bo.tags = './tags;,tags' -- custom
        bo.textwidth = 120 -- custom
        bo.undofile = true -- custom
        bo.varsofttabstop = ''
        bo.vartabstop = ''
        bo.wrapmargin = 0
    end
    -- Global defaults for new buffers, for the options Matt customized
    -- via go.* in init.lua. The guarded block above only touches the
    -- current buffer; these make the choice stick for buffers opened later.
    vim.go.expandtab = true
    vim.cmd('filetype plugin on')
    vim.cmd('filetype plugin indent on')
end

return M
