--- Contextive.LanguageServer language-server config — starts the files using ubiquitous-language hints tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `Contextive.LanguageServer` tutor whenever you open files using
--- ubiquitous-language hints. It only takes effect if `Contextive.LanguageServer` is installed on your computer.
---@module 'lsp.contextive_ls'
-- /qompassia/Diver/lsp/contextive_ls.lua
-- Qompass AI Contextive LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/dev-cycles/contextive
-- Download and install the Contextive language server:
-- curl -L -o Contextive.LanguageServer.zip \
--   "https://github.com/dev-cycles/contextive/releases/download/v1.17.8/Contextive.LanguageServer-linux-x64-1.17.8.zip"

return ---@type vim.lsp.Config
{
    cmd = {
        'Contextive.LanguageServer',
    },
    root_markers = {
        '.contextive',
        'glossary.yml',
        '.glossary.yml',
    },
}
