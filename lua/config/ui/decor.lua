-- /qompassai/Diver/lua/config/ui/decor.lua
-- Qompass AI Diver UI Decorations Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local ts = vim.treesitter
local NS_CONTEXT = vim.api.nvim_create_namespace('TSContext')
local NS_VIRT = vim.api.nvim_create_namespace('TSVirt')
local NS_SIGNS = vim.api.nvim_create_namespace('TSSigns')
local function get_root(bufnr, lang)
    bufnr = bufnr or 0
    lang = lang or vim.bo[bufnr].filetype
    local ok, parser = pcall(ts.get_parser, bufnr, lang)
    if not ok or not parser then
        return
    end
    local tree = parser:parse()[1]
    return tree and tree:root()
end
local function get_node(bufnr, win)
    bufnr = bufnr or 0
    win = win or 0
    local pos = vim.api.nvim_win_get_cursor(win)
    local row, col = pos[1] - 1, pos[2]
    return ts.get_node({ bufnr = bufnr, pos = { row, col } })
end
local function select_node(node)
    if not node then
        return
    end
    local srow, scol, erow, ecol = node:range()
    vim.fn.setpos('v', { 0, srow + 1, scol + 1, 0 })
    vim.fn.setpos('.', { 0, erow + 1, ecol, 0 })
    vim.cmd('normal! gv')
end
local function inc_node()
    select_node(get_node(0, 0))
end
local function inc_parent()
    local node = get_node(0, 0)
    if not node then
        return
    end
    select_node(node:parent())
end
local function dec_node()
    local node = get_node(0, 0)
    if not node then
        return
    end
    local child = node:named_child(0)
    if child then
        select_node(child)
    end
end
local function select_around(type_name)
    local node = get_node(0, 0)
    while node and node:type() ~= type_name do
        node = node:parent()
    end
    select_node(node)
end
local function select_inner_function()
    local node = get_node(0, 0)
    while node and node:type() ~= 'function_declaration' do
        node = node:parent()
    end
    if not node then
        return
    end
    local body = node:field('body')[1]
    select_node(body or node)
end
local function current_scope_line(bufnr)
    bufnr = bufnr or 0
    local node = get_node(bufnr, 0)
    if not node then
        return
    end
    while node do
        local type_ = node:type()
        if type_ == 'function_declaration' or type_ == 'function_definition' or type_ == 'method_declaration' then
            local srow = node:range()
            return srow
        end
        node = node:parent()
    end
end
local function setup_context_provider()
    vim.api.nvim_set_decoration_provider(NS_CONTEXT, {
        on_win = function(_, win, bufnr, _)
            if not vim.treesitter.highlighter.active[bufnr] then
                return false
            end
            return win == vim.api.nvim_get_current_win()
        end,
        on_line = function(_, _, bufnr, line)
            vim.api.nvim_buf_clear_namespace(bufnr, NS_CONTEXT, line, line + 1)
            local scope_line = current_scope_line(bufnr)
            if not scope_line or scope_line ~= line then
                return
            end
            local label = ('TS scope @ %d'):format(line + 1)
            vim.api.nvim_buf_set_extmark(bufnr, NS_CONTEXT, line, -1, {
                virt_text = { { label, 'Comment' } },
                virt_text_pos = 'eol',
                hl_mode = 'combine',
            })
        end,
    })
end
local function show_under_cursor()
    local bufnr = 0
    vim.api.nvim_buf_clear_namespace(bufnr, NS_VIRT, 0, -1)

    local node = get_node(bufnr, 0)
    if not node then
        return
    end
    local srow, scol, erow, ecol = node:range()
    local info = ('%s [%d:%d - %d:%d]'):format(node:type(), srow, scol, erow, ecol)

    vim.api.nvim_buf_set_extmark(bufnr, NS_VIRT, srow, scol, {
        virt_text = { { ' ⟵ ' .. info, 'DiagnosticHint' } },
        virt_text_pos = 'inline',
        hl_mode = 'combine',
    })
    vim.api.nvim_buf_set_extmark(bufnr, NS_VIRT, erow, 0, {
        virt_lines = {
            { { ' TS node: ' .. node:type(), 'Comment' } },
        },
        virt_lines_above = false,
    })
end
local function mark_functions(bufnr)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, NS_SIGNS, 0, -1)

    local ft = vim.bo[bufnr].filetype
    local root = get_root(bufnr, ft)
    if not root then
        return
    end
    local ok, query = pcall(
        ts.query.parse,
        ft,
        [[
    (function_declaration) @fn
  ]]
    )
    if not ok or not query then
        return
    end
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        if capture_name == 'fn' then
            local srow = node:range()
            vim.api.nvim_buf_set_extmark(bufnr, NS_SIGNS, srow, 0, {
                sign_text = 'ƒ',
                sign_hl_group = 'Function',
                number_hl_group = 'Function',
            })
        end
    end
end
local function setup_function_signs_autocmd()
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
        group = vim.api.nvim_create_augroup('TSDecorSigns', { clear = true }),
        callback = function(args)
            mark_functions(args.buf)
        end,
    })
end
M.setup = function(opts)
    opts = opts or {}
    if opts.incremental_selection ~= false then
        vim.keymap.set('x', 'gn', inc_node, { desc = 'TS select node' })
        vim.keymap.set('x', 'gN', inc_parent, { desc = 'TS select parent' })
        vim.keymap.set('x', 'g-', dec_node, { desc = 'TS select child' })
    end
    if opts.textobjects ~= false then
        vim.keymap.set({ 'x', 'o' }, 'af', function()
            select_around('function_declaration')
        end, { desc = 'around function (TS)' })
        vim.keymap.set({ 'x', 'o' }, 'if', select_inner_function, {
            desc = 'inner function (TS)',
        })
    end
    if opts.context ~= false then
        setup_context_provider()
    end
    if opts.inline_inspector ~= false then
        vim.keymap.set('n', '<leader>ti', show_under_cursor, {
            desc = 'TS inline node info',
        })
    end
    if opts.function_signs ~= false then
        setup_function_signs_autocmd()
    end
end
return M