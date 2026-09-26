-- Native buffer-capability LSP actions. Native gr*, gO, K and i_CTRL-S stay intact.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('mappings._core')
local M = {}
local OWNER = 'lspmap'
local ACTIONS = {
    { label = 'Code action', method = 'textDocument/codeAction', run = vim.lsp.buf.code_action },
    { label = 'Declaration', method = 'textDocument/declaration', run = vim.lsp.buf.declaration },
    { label = 'Definition', method = 'textDocument/definition', run = vim.lsp.buf.definition },
    {
        label = 'Document symbols',
        method = 'textDocument/documentSymbol',
        run = vim.lsp.buf.document_symbol,
    },
    { label = 'Hover', method = 'textDocument/hover', run = vim.lsp.buf.hover },
    {
        label = 'Implementation',
        method = 'textDocument/implementation',
        run = vim.lsp.buf.implementation,
    },
    { label = 'References', method = 'textDocument/references', run = vim.lsp.buf.references },
    { label = 'Rename', method = 'textDocument/rename', run = vim.lsp.buf.rename },
    {
        label = 'Signature help',
        method = 'textDocument/signatureHelp',
        run = vim.lsp.buf.signature_help,
    },
    {
        label = 'Type definition',
        method = 'textDocument/typeDefinition',
        run = vim.lsp.buf.type_definition,
    },
    {
        label = 'Workspace symbols',
        method = 'workspace/symbol',
        run = vim.lsp.buf.workspace_symbol,
    },
}

function M.actions(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local items = {}
    for _, action in ipairs(ACTIONS) do
        if core.supports(bufnr, action.method) then
            items[#items + 1] = action
        end
    end
    core.select(bufnr, items, 'LSP actions: ' .. vim.bo[bufnr].filetype)
end

local function info(bufnr)
    local lines = { 'Attached LSP clients for ' .. vim.bo[bufnr].filetype }
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    table.sort(clients, function(a, b)
        return a.name < b.name
    end)
    for _, client in ipairs(clients) do
        lines[#lines + 1] = ('%s [id=%d]'):format(client.name, client.id)
    end
    core.show(lines, 'LSP clients')
end

local function attach(bufnr)
    local maps = {}
    if core.source(bufnr) and #vim.lsp.get_clients({ bufnr = bufnr }) > 0 then
        maps = {
            {
                lhs = '<LocalLeader>la',
                rhs = function()
                    M.actions(bufnr)
                end,
                desc = 'Choose supported LSP action',
            },
            {
                lhs = '<LocalLeader>li',
                rhs = function()
                    info(bufnr)
                end,
                desc = 'Attached LSP clients',
            },
        }
        if core.supports(bufnr, 'textDocument/inlayHint') then
            maps[#maps + 1] = {
                lhs = '<LocalLeader>lh',
                desc = 'Toggle inlay hints',
                rhs = function()
                    local filter = { bufnr = bufnr }
                    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
                end,
            }
        end
        maps[#maps + 1] = {
            lhs = '<LocalLeader>lk',
            desc = 'Audit server code actions',
            rhs = core.command('LspCodeActionAudit'),
        }
        maps[#maps + 1] = {
            lhs = '<LocalLeader>lc',
            desc = 'Code actions here',
            rhs = core.command('CodeActionsHere'),
            mode = { 'n', 'x' },
        }
        maps[#maps + 1] = {
            lhs = '<LocalLeader>ls',
            desc = 'Toggle semantic tokens',
            rhs = core.command('LspSemanticTokensToggle'),
        }
        for _, item in ipairs({
            { 'gD', 'textDocument/declaration', vim.lsp.buf.declaration, 'Declaration' },
            { 'gd', 'textDocument/definition', vim.lsp.buf.definition, 'Definition' },
        }) do
            if core.supports(bufnr, item[2]) then
                maps[#maps + 1] = { lhs = item[1], rhs = item[3], desc = item[4] }
            end
        end
    end
    core.install(OWNER, bufnr, maps)
end

-- Preserve Diver's existing config.core.lsp on_attach integration.
function M.on_attach(event)
    if core.usable(event.buf) then
        attach(event.buf)
    end
end

function M.setup()
    core.watch(OWNER, attach)
end
function M.teardown()
    core.teardown(OWNER)
end
M.setup_lspmap = M.setup
return M
