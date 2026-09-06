-- #################################################################
-- /qompassai/Diver/lsp/fennel_ls.lua
-- Qompass AI Diver Fennel Language Server Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://git.sr.ht/~xerool/fennel-ls
---@source https://xerool.net/fennel-ls/docs/manual.html
---@source https://github.com/bakpakin/Fennel
---@source https://neovim.io/doc/user/lsp.html
--
-- Tiger policy:
--
--   fennel-ls is the authoritative Fennel analyzer.
--
-- It owns:
--
--   * Fennel compiler diagnostics
--   * fennel-ls custom lint diagnostics
--   * unused-definition diagnostics
--   * cross-file module analysis
--   * completion
--   * hover
--   * goto definition
--   * references
--   * rename
--   * macro analysis
--   * builtin/global analysis
--   * library/docset completion
--
-- Do not additionally run:
--
--   fennel-ls --lint
--
-- through the native linter framework for attached Fennel buffers, because
-- that duplicates the same analyzer and produces duplicate diagnostics.
--
-- Project-specific Fennel behavior belongs in:
--
--   flsproject.fnl
--
-- rather than being duplicated here.

local diagnostic = vim.diagnostic
local lsp = vim.lsp

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 4096
local SOURCE = 'fennel-ls'

---@type string[]
local ROOT_MARKERS = {
    'flsproject.fnl',
    {
        '.nfnl.fnl',
        'fennel.lua',
    },
    {
        'Makefile',
        'justfile',
    },
    {
        '.git',
        '.hg',
    },
}

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
    if #value <= limit then
        return value
    end

    if limit <= 3 then
        return value:sub(
            1,
            limit
        )
    end

    return value:sub(
        1,
        limit - 3
    ) .. '...'
end

---@param value string
---@return string
local function compact(value)
    return vim.trim(
        value:gsub(
            '%s+',
            ' '
        )
    )
end

---@param severity integer?
---@return integer
local function normalize_severity(severity)
    if severity == nil then
        return diagnostic.severity.WARN
    end

    if severity < diagnostic.severity.ERROR then
        return diagnostic.severity.ERROR
    end

    if severity > diagnostic.severity.HINT then
        return diagnostic.severity.HINT
    end

    return severity
end

---@param result lsp.PublishDiagnosticsParams
---@param ctx lsp.HandlerContext
local function diagnostics_handler(
    result,
    ctx
)
    if
        result == nil
        or type(result.diagnostics) ~= 'table'
    then
        return
    end

    if #result.diagnostics > MAX_DIAGNOSTICS then
        local limited = {}

        for index = 1, MAX_DIAGNOSTICS do
            limited[index] =
                result.diagnostics[index]
        end

        result.diagnostics = limited
    end

    for _, item in ipairs(
        result.diagnostics
    ) do
        if type(item.message) == 'string' then
            item.message = truncate(
                compact(item.message),
                MAX_MESSAGE_BYTES
            )
        end

        item.severity = normalize_severity(
            item.severity
        )

        if
            item.source == nil
            or item.source == ''
        then
            item.source = SOURCE
        end
    end

    lsp.handlers[
        'textDocument/publishDiagnostics'
    ](
        nil,
        result,
        ctx
    )
end

---@type vim.lsp.ClientCapabilities
local capabilities = {
    workspace = {
        configuration = true,

        workspaceFolders = true,
    },

    textDocument = {
        completion = {
            contextSupport = true,

            completionItem = {
                commitCharactersSupport = true,

                deprecatedSupport = true,

                documentationFormat = {
                    'markdown',
                    'plaintext',
                },

                insertReplaceSupport = true,

                insertTextModeSupport = {
                    valueSet = {
                        1,
                        2,
                    },
                },

                labelDetailsSupport = true,

                preselectSupport = true,

                resolveSupport = {
                    properties = {
                        'documentation',
                        'detail',
                        'additionalTextEdits',
                    },
                },

                snippetSupport = true,

                tagSupport = {
                    valueSet = {
                        1,
                    },
                },
            },
        },

        definition = {
            linkSupport = true,
        },

        diagnostic = {
            dynamicRegistration = false,

            relatedDocumentSupport = true,
        },

        documentSymbol = {
            hierarchicalDocumentSymbolSupport = true,

            labelSupport = true,

            symbolKind = {
                valueSet = {
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9,
                    10,
                    11,
                    12,
                    13,
                    14,
                    15,
                    16,
                    17,
                    18,
                    19,
                    20,
                    21,
                    22,
                    23,
                    24,
                    25,
                    26,
                },
            },
        },

        hover = {
            contentFormat = {
                'markdown',
                'plaintext',
            },
        },

        publishDiagnostics = {
            codeDescriptionSupport = true,

            dataSupport = true,

            relatedInformation = true,

            tagSupport = {
                valueSet = {
                    1,
                    2,
                },
            },

            versionSupport = true,
        },

        references = {
            dynamicRegistration = false,
        },

        rename = {
            dynamicRegistration = false,

            prepareSupport = true,
        },

        synchronization = {
            didSave = true,

            dynamicRegistration = false,

            willSave = false,

            willSaveWaitUntil = false,
        },
    },
}

---@type vim.lsp.Config
return {
    cmd = {
        'fennel-ls',
    },

    filetypes = {
        'fennel',
    },

    root_markers = ROOT_MARKERS,

    single_file_support = true,

    capabilities = capabilities,

    flags = {
        debounce_text_changes = 150,
    },

    handlers = {
        ['textDocument/publishDiagnostics'] =
            diagnostics_handler,
    },

    settings = {},
}