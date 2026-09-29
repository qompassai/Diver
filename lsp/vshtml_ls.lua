#!/usr/bin/env lua5.1
-- /qompassai/Diver/lsp/vshtml_ls.lua
-- Qompass AI VSCode HTML Service LSP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- npm install -g vscode-langservers-extracted
--
-- The VSCode HTML language service over stdio
-- (vscode-html-language-server --stdio).
--
-- Unlisted: not enabled by default (absent from the servers table in
-- lsp/init.lua); html_ls.lua is the active HTML config. This spec carries
-- the full explicit settings schema so it can be enabled as a drop-in
-- alternative.
--
-- Upstream: https://github.com/hrsh7th/vscode-langservers-extracted
-- Service:  https://github.com/microsoft/vscode-html-languageservice
--
-- NOTE: the server advertises no codeActionProvider -- verified against
-- extensions/html-language-features/server/src/htmlServer.ts on
-- microsoft/vscode main, whose ServerCapabilities list has no
-- codeActionProvider entry. No code-action wiring here by design, not by
-- omission.
return ---@type vim.lsp.Config
{
    cmd = {
        'vscode-html-language-server',
        '--stdio',
    },
    filetypes = {
        'html',
    },
    init_options = {
        provideFormatter = true,
        embeddedLanguages = {
            css = true,
            javascript = true,
        },
        configurationSection = {
            'css',
            'html',
            'javascript',
        },
    },
    root_markers = {
        '.git',
        'package.json',
    },
    -- Every key below is a real html.* / css.* contribution point with its
    -- upstream default, verified against
    -- extensions/html-language-features/package.json on microsoft/vscode
    -- main. Null-default keys (html.format.maxPreserveNewLines,
    -- html.format.wrapAttributesIndentSize, html.customData) are omitted:
    -- omitted is the null default.
    settings = {
        css = {
            validate = true,
        },
        html = {
            autoClosingTags = true,
            autoCreateQuotes = true,
            completion = {
                attributeDefaultValue = 'doublequotes',
            },
            format = {
                enable = true,
                contentUnformatted = 'pre,code,textarea',
                extraLiners = 'head, body, /html',
                indentHandlebars = false,
                indentInnerHtml = false,
                preserveNewLines = true,
                templating = false,
                unformatted = 'wbr',
                unformattedContentDelimiter = '',
                wrapAttributes = 'auto',
                wrapLineLength = 120,
            },
            hover = {
                documentation = true,
                references = true,
            },
            suggest = {
                hideEndTagSuggestions = false,
                html5 = true,
            },
            trace = {
                server = 'off',
            },
            validate = {
                scripts = true,
                styles = true,
            },
        },
    },
}
