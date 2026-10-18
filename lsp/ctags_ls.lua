#!/usr/bin/env lua5.1
-- /qompassai/Diver/lsp/ctags_ls.lua
-- Qompass AI Diver CTags LSP Spec
---@source https://github.com/netmute/ctags-lsp

---@type vim.lsp.Config
return {
    cmd = {
        'ctags-lsp',
    },
    root_markers = {
        'tags',
        '.tags',
        '.git',
    },
}
