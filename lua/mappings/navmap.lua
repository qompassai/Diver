-- /qompassai/Diver/lua/mappings/navmap.lua
-- Navigation owns leader n*, quickfix q*, location lists l*; LSP actions are buffer-local.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('mappings._core')
local qf = require('config.core.qf')
local M = {}
local OWNER = 'navmap'
local modules = {}

local function invoke(module, method, ...)
    local args = { n = select('#', ...), ... }
    return function()
        local target = modules[module]
        if target and type(target[method]) == 'function' then
            return target[method](unpack(args, 1, args.n))
        end
        core.notify(module .. '.' .. method .. ' is unavailable')
    end
end

local function structure()
    local items = {}
    for _, spec in ipairs({
        { 'class.outer', 'Class', 'textobjects' },
        { 'function.outer', 'Function', 'textobjects' },
        { 'conditional.outer', 'Conditional', 'textobjects' },
        { 'loop.outer', 'Loop', 'textobjects' },
        { 'fold', 'Fold', 'folds' },
    }) do
        for _, direction in ipairs({ { true, 'Next' }, { false, 'Previous' } }) do
            items[#items + 1] = {
                label = direction[2] .. ' ' .. spec[2],
                run = function()
                    local ok, err =
                        require('config.core.tree').jump(spec[1], direction[1], false, spec[3])
                    if not ok then
                        core.notify(err)
                    end
                end,
            }
        end
    end
    core.select(api.nvim_get_current_buf(), items, 'Tree-sitter captures:')
end

local function attach(bufnr)
    local maps = {}
    if core.source(bufnr) then
        if core.supports(bufnr, 'textDocument/documentSymbol') then
            maps[#maps + 1] = {
                lhs = '<LocalLeader>nd',
                rhs = invoke('fzf', 'document_symbols'),
                desc = 'Document symbols',
            }
        end
        if core.supports(bufnr, 'workspace/symbol') then
            maps[#maps + 1] = {
                lhs = '<LocalLeader>nw',
                rhs = invoke('fzf', 'workspace_symbols'),
                desc = 'Workspace symbols',
            }
        end
        if core.supports(bufnr, 'textDocument/codeAction') then
            maps[#maps + 1] = {
                lhs = '<LocalLeader>nr',
                mode = { 'n', 'x' },
                rhs = function()
                    vim.lsp.buf.code_action({
                        context = { only = { 'refactor' }, diagnostics = {} },
                    })
                end,
                desc = 'Filetype LSP refactor actions',
            }
        end
        local parser = vim.treesitter.get_parser(bufnr, nil, { error = false })
        if parser then
            maps[#maps + 1] = {
                lhs = '<LocalLeader>nt',
                rhs = structure,
                desc = 'Tree-sitter capture navigation',
            }
        end
    elseif vim.bo[bufnr].filetype == 'qf' then
        maps = {
            {
                lhs = 'dd',
                rhs = function()
                    local row = api.nvim_win_get_cursor(0)[1]
                    local ok, err = qf.remove(
                        nil,
                        row,
                        math.min(row + vim.v.count1 - 1, api.nvim_buf_line_count(0))
                    )
                    if not ok then
                        core.notify(err)
                    end
                end,
                desc = 'Remove quickfix entries into history',
            },
            {
                lhs = 'd',
                mode = 'x',
                rhs = function()
                    local first, last = vim.fn.line('v'), vim.fn.line('.')
                    local ok, err = qf.remove(nil, math.min(first, last), math.max(first, last))
                    if not ok then
                        core.notify(err)
                    end
                    api.nvim_feedkeys(
                        api.nvim_replace_termcodes('<Esc>', true, false, true),
                        'n',
                        false
                    )
                end,
                desc = 'Remove selected quickfix entries into history',
            },
            {
                lhs = 'p',
                rhs = function()
                    qf.preview(nil, vim.fn.line('.'))
                end,
                desc = 'Preview quickfix entry',
            },
            {
                lhs = 'q',
                rhs = function()
                    qf.run('close')
                end,
                desc = 'Close this list',
            },
        }
    end
    core.install(OWNER, bufnr, maps)
end

function M.teardown()
    core.teardown(OWNER)
    for _, name in ipairs({ 'fzf', 'ripgrep', 'searxng' }) do
        if modules[name] then
            modules[name].cancel()
        end
    end
    if modules.nt then
        modules.nt.cancel_operations()
    end
end

function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table')
    M.teardown()
    for _, name in ipairs({ 'fzf', 'nt', 'ripgrep', 'searxng' }) do
        modules[name] = require('config.nav.' .. name)
    end
    local ok, err = modules.fzf.setup(opts.fzf)
    assert(ok, err)
    modules.nt.setup(opts.nt)
    modules.searxng.setup(opts.searxng)
    qf.setup()
    local maps = {
        { lhs = '<leader>nb', rhs = invoke('fzf', 'buffers'), desc = 'Find buffer' },
        { lhs = '<leader>nc', rhs = invoke('fzf', 'commands'), desc = 'Find command' },
        { lhs = '<leader>ne', rhs = invoke('nt', 'toggle'), desc = 'Toggle native explorer' },
        { lhs = '<leader>nf', rhs = invoke('fzf', 'files'), desc = 'Find file' },
        { lhs = '<leader>ng', rhs = invoke('ripgrep', 'search'), desc = 'Ripgrep to quickfix' },
        { lhs = '<leader>nh', rhs = invoke('fzf', 'help_tags'), desc = 'Find help tag' },
        { lhs = '<leader>ni', rhs = invoke('fzf', 'git_status'), desc = 'Find Git changed file' },
        {
            lhs = '<leader>nl',
            rhs = invoke('ripgrep', 'search', nil, { kind = 'loc' }),
            desc = 'Ripgrep to location list',
        },
        { lhs = '<leader>nm', rhs = invoke('fzf', 'marks'), desc = 'Find mark' },
        { lhs = '<leader>np', rhs = invoke('fzf', 'projects'), desc = 'Find project' },
        { lhs = '<leader>nr', rhs = invoke('searxng', 'results'), desc = 'Reopen SearXNG results' },
        { lhs = '<leader>ns', rhs = invoke('searxng', 'search'), desc = 'Search SearXNG' },
        { lhs = '<leader>nu', rhs = invoke('searxng', 'next_page'), desc = 'Next SearXNG page' },
        { lhs = '<leader>nw', rhs = invoke('ripgrep', 'word'), desc = 'Ripgrep cursor word' },
        {
            lhs = '<leader>nx',
            rhs = function()
                modules.fzf.cancel()
                modules.ripgrep.cancel()
                modules.searxng.cancel()
                modules.nt.cancel_operations()
            end,
            desc = 'Cancel navigation work',
        },
    }
    for _, kind in ipairs({ 'loc', 'qf' }) do
        local prefix = kind == 'loc' and 'l' or 'q'
        for _, entry in ipairs(qf.entries) do
            maps[#maps + 1] = {
                lhs = '<leader>' .. prefix .. entry[1],
                rhs = function()
                    qf.run(entry[2], kind)
                end,
                desc = (kind == 'loc' and 'Location list: ' or 'Quickfix: ') .. entry[3],
            }
        end
    end
    core.watch(OWNER, attach)
    core.install(OWNER, 0, maps)
end
M.setup_navmap = M.setup
return M
