-- /qompassai/Diver/after/ftplugin/julia.lua
-- Qompass AI Diver After Julia Filetype Plugin
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local b = vim.b
local c = vim.fn.col('.')
local l = vim.fn.line('.')
local g = vim.g
local o = vim.o
local save_cpo = vim.o.cpoptions
if b.did_ftplugin then
    return
end
b.did_ftplugin = 1
o.cpoptions = 'vim'
vim.opt_local.include = [[^\s*\%(reload\|include\)\>]]
vim.opt_local.suffixesadd:append('.jl')
vim.opt_local.comments = ':#'
vim.opt_local.commentstring = '#=%s=#'
vim.opt_local.cinoptions:append('#1')
vim.opt_local.define = [[^\s*macro\>]]
vim.opt_local.formatoptions:remove('t')
vim.opt_local.formatoptions:append('croql')
b.julia_vim_loaded = 1
b.undo_ftplugin = 'setlocal include< suffixesadd< comments< commentstring<'
    .. ' define< fo< cinoptions< completefunc<'
    .. ' | unlet! b:julia_vim_loaded'
if g.loaded_matchit ~= nil then
    b.match_ignorecase = 0
    b.julia_begin_keywords = [[\%(\.\s*\|@\)\@<!\<\%(function\|macro\|begin]]
        .. [[\|mutable\s\+struct\|\%(mutable\s\+\)\@<!struc]]
        .. [[t\|\%(abstract\|primitive\)\s\+type\|let\|do\|\%(bare\)\?module]]
        .. [[\|quote\|if\|for\|whil]]
        .. [[e\|try\)\>]]
    local macro_regex = [[\%(@\%([#(]\@!\S\)\+\|\<\%(local\|global\)\)\s\+]]
    local julia_begin_keywords = vim.b.julia_begin_keywords
    local nomacro_expr = [[\%(']] .. macro_regex .. [[\)\@<!]]
    local yesmacro_expr = nomacro_expr .. [[\%(']] .. macro_regex .. [[\)\+]]
    vim.b.julia_begin_keywordsm = [[\%(]]
        .. yesmacro_expr
        .. julia_begin_keywords
        .. [[\)\|]]
        .. [[\%(]]
        .. nomacro_expr
        .. julia_begin_keywords
        .. [[\)]]
    b.julia_end_keywords = [[\<end\>]]
    local function JuliaGetMatchWords()
        local function syn_name(line, col)
            return vim.fn.synIDattr(vim.fn.synID(line, col, 1), 'name')
        end
        local attr = syn_name(l, c)
        local c1 = c
        while attr == 'juliaMacro' or vim.fn.expand('<cword>'):match([[\v\<(global|local)\>]]) ~= nil do
            vim.cmd('normal! W')
            if vim.fn.line('.') > l or vim.fn.col('.') == c1 then
                vim.fn.cursor(l, c)
                return ''
            end
            attr = syn_name(l, vim.fn.col('.'))
            c1 = vim.fn.col('.')
        end
        vim.fn.cursor(l, c)
        if attr == 'juliaConditional' then
            return vim.b.julia_begin_keywordsm .. [[:\<\%(elseif\|else\)\>:]] .. vim.b.julia_end_keywords
        elseif attr:match([[\<\%(juliaRepeat\|juliaRepKeyword\)\>]]) then
            return vim.b.julia_begin_keywordsm .. [[:\<\%(break\|continue\)\>:]] .. vim.b.julia_end_keywords
        elseif attr == 'juliaBlKeyword' then
            return vim.b.julia_begin_keywordsm .. ':' .. vim.b.julia_end_keywords
        elseif attr == 'juliaException' then
            return vim.b.julia_begin_keywordsm .. [[:\<\%(catch\|else\|finally\)\>:]] .. vim.b.julia_end_keywords
        end
        return [[\<\>:\<\>]]
    end
    _G.JuliaGetMatchWords = JuliaGetMatchWords
    vim.cmd([[
    function! JuliaGetMatchWords() abort
      return v:lua.JuliaGetMatchWords()
    endfunction
  ]])
    b.match_words = 'JuliaGetMatchWords()'
    b.match_skip = [[synIDattr(synID(line("."),col("."),0),"name") =~# ]]
        .. [["\<julia\%(Comprehension\%(For\|If\)\|RangeKeyword\|Comment\%([LM]\|Delim\)\|\%([bs]\|S]]
        .. [[hell\|Printf\|Doc\)\?String\|StringPrefixed\|DocStringM\(Raw\)\?\|RegEx\|SymbolS\?\|D]]
        .. [[otted\)\>"]]
    b.undo_ftplugin = vim.b.undo_ftplugin
        .. ' | unlet! b:match_words b:match_skip b:match_ignorecase'
        .. ' | unlet! b:julia_begin_keywords b:julia_end_keywords'
        .. ' | delfunction JuliaGetMatchWords'
end
o.cpoptions = save_cpo
