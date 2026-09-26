-- #################################################################
-- /qompassai/Diver/lua/refactor/lsp.lua
-- Native LSP-backed semantic refactors for Neovim 0.13+
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

local core = require('refactor.core')

local M = {}

local CLIENT_COUNT_MAX = 32

local specs = {
    extract = {
        only = { 'refactor.extract' },
    },
    extract_var = {
        only = { 'refactor.extract' },
        title = { 'variable', 'constant', 'local' },
    },
    extract_func = {
        only = { 'refactor.extract' },
        title = { 'function', 'method', 'procedure' },
    },
    inline = {
        only = { 'refactor.inline' },
    },
    inline_var = {
        only = { 'refactor.inline' },
        title = { 'variable', 'constant', 'local' },
    },
    inline_func = {
        only = { 'refactor.inline' },
        title = { 'function', 'method', 'procedure' },
    },
    rewrite = {
        only = { 'refactor.rewrite' },
    },
    refactor = {
        only = { 'refactor' },
    },
}

---@param bufnr integer
---@return boolean
local function has_code_action_client(bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })

    if #clients > CLIENT_COUNT_MAX then
        core.notify(
            ('refusing to inspect %d LSP clients; maximum is %d'):format(#clients, CLIENT_COUNT_MAX),
            vim.log.levels.ERROR
        )
        return false
    end

    for _, client in ipairs(clients) do
        if client:supports_method('textDocument/codeAction', bufnr) then
            return true
        end
    end

    return false
end

---@param hints string[]?
---@return fun(action: lsp.CodeAction|lsp.Command, client_id: integer): boolean? | nil
local function make_filter(hints)
    if not hints or #hints == 0 then
        return nil
    end

    return function(action, _)
        local title = (action.title or ''):lower()

        for _, hint in ipairs(hints) do
            if title:find(hint, 1, true) then
                return true
            end
        end

        return false
    end
end

---@class refactor.LspOpts
---@field bufnr? integer
---@field range? refactor.NativeRange
---@field apply? boolean
---@field strict_title? boolean

---@param name string
---@param opts? refactor.LspOpts
---@return nil
function M.run(name, opts)
    opts = opts or {}

    local spec = specs[name]
    if not spec then
        core.notify(('unknown refactor action: %s'):format(name), vim.log.levels.ERROR)
        return
    end

    local bufnr = core.bufnr(opts.bufnr)
    if not has_code_action_client(bufnr) then
        core.notify('no attached LSP client supports textDocument/codeAction', vim.log.levels.WARN)
        return
    end

    local filter = opts.strict_title == false and nil or make_filter(spec.title)

    vim.lsp.buf.code_action({
        apply = opts.apply ~= false,
        context = {
            only = spec.only,
            triggerKind = (vim.lsp.protocol.CodeActionTriggerKind or {}).Invoked or 1,
        },
        filter = filter,
        range = opts.range,
    })
end

---@param opts? {bufnr?: integer}
---@return nil
function M.rename(opts)
    opts = opts or {}

    local bufnr = core.bufnr(opts.bufnr)

    -- SCIP pre-flight: warn when the whole-project index is fresher than
    -- LSP's open-buffer view, so a rename does not silently miss files.
    -- Advisory only; the rename always proceeds.
    local ok_scip, scip = pcall(require, 'refactor.scip')

    if ok_scip then
        scip.confirm(scip.preflight(bufnr))
    end

    vim.lsp.buf.rename(nil, {
        bufnr = bufnr,
    })
end

return M
