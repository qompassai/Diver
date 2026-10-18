-- /qompassai/Diver/lua/config/ui/decor.lua
-- Qompass AI Diver UI Decorations Config
---@module 'config.ui.decor'
local M = {} ---@version JIT
local ts = vim.treesitter
local NS_CONTEXT = vim.api.nvim_create_namespace('TSContext')
local NS_END_LABELS = vim.api.nvim_create_namespace('TSEndLabels')
local NS_SIGNS = vim.api.nvim_create_namespace('TSSigns')
local NS_VIRT = vim.api.nvim_create_namespace('TSVirt')
-- Node types closed by an `end` token; candidates for an end label.
local END_BLOCK_TYPES = {
    do_statement = true,
    for_statement = true,
    function_declaration = true,
    function_definition = true,
    if_statement = true,
    while_statement = true,
}
-- A block earns an end label only when its closing line sits at least
-- this far below its opening line (a span of more than 3 lines), and
-- the copied opening line is truncated to this many characters.
local END_LABEL_MAX_CHARS = 80
local END_LABEL_MIN_SPAN = 3
-- Global default for end labels; a buffer overrides it through
-- vim.b[bufnr].decor_end_labels (see toggle_end_labels).
local end_labels_global = true
local function get_node(bufnr, win)
    bufnr = bufnr or 0
    win = win or 0
    local pos = vim.api.nvim_win_get_cursor(win)
    local row, col = pos[1] - 1, pos[2]
    return ts.get_node({
        bufnr = bufnr,
        pos = {
            row,
            col,
        },
    })
end
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
local function end_labels_active(bufnr)
    local buffer_value = vim.b[bufnr].decor_end_labels
    if buffer_value ~= nil then
        return buffer_value
    end
    return end_labels_global
end
local function end_label_row(node)
    local last_child = node:child(node:child_count() - 1)
    if last_child and last_child:type() == 'end' then
        local row = last_child:range()
        return row
    end
    local _, _, end_row, end_col = node:range()
    if end_col == 0 and end_row > 0 then
        return end_row - 1
    end
    return end_row
end
local function end_label_text(bufnr, node)
    local start_row = node:range()
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
    local text = vim.trim((line:gsub('%s+', ' ')))
    if #text > END_LABEL_MAX_CHARS then
        text = text:sub(1, END_LABEL_MAX_CHARS - 3) .. '...'
    end
    return '-- ' .. text
end
local function mark_end_labels(bufnr)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, NS_END_LABELS, 0, -1)
    if vim.bo[bufnr].filetype ~= 'lua' or not end_labels_active(bufnr) then
        return
    end
    local root = get_root(bufnr, 'lua')
    if not root then
        return
    end
    local ok, query = pcall(
        ts.query.parse,
        'lua',
        [[
    [
      (do_statement)
      (for_statement)
      (function_declaration)
      (function_definition)
      (if_statement)
      (while_statement)
    ] @block
  ]]
    )
    if not ok or not query then
        return
    end
    local labeled_rows = {}
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        if query.captures[id] == 'block' and END_BLOCK_TYPES[node:type()] then
            local start_row = node:range()
            local label_row = end_label_row(node)
            if label_row - start_row >= END_LABEL_MIN_SPAN and not labeled_rows[label_row] then
                labeled_rows[label_row] = true
                vim.api.nvim_buf_set_extmark(bufnr, NS_END_LABELS, label_row, 0, {
                    virt_text = { { end_label_text(bufnr, node), 'Comment' } },
                    virt_text_pos = 'eol',
                    hl_mode = 'combine',
                })
            end
        end
    end
end
local function toggle_end_labels(global_scope)
    if global_scope then
        end_labels_global = not end_labels_global
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            local overridden = vim.b[bufnr].decor_end_labels ~= nil
            if vim.api.nvim_buf_is_loaded(bufnr) and not overridden then
                mark_end_labels(bufnr)
            end
        end
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(bufnr, 'decor_end_labels', not end_labels_active(bufnr))
    mark_end_labels(bufnr)
end
local function select_node(node)
    if not node then
        return
    end
    local srow, scol, erow, ecol = node:range()
    vim.fn.setpos('v', {
        0,
        srow + 1,
        scol + 1,
        0,
    })
    vim.fn.setpos('.', {
        0,
        erow + 1,
        ecol,
        0,
    })
    vim.cmd('normal! gv')
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
local function setup_end_labels_autocmd()
    vim.api.nvim_create_autocmd({
        'BufEnter',
        'BufWritePost',
    }, {
        group = vim.api.nvim_create_augroup('TSDecorEndLabels', {
            clear = true,
        }),
        callback = function(args)
            mark_end_labels(args.buf)
        end,
    })
end
local function setup_function_signs_autocmd()
    vim.api.nvim_create_autocmd({
        'BufEnter',
        'BufWritePost',
    }, {
        group = vim.api.nvim_create_augroup('TSDecorSigns', {
            clear = true,
        }),
        callback = function(args)
            mark_functions(args.buf)
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
        virt_text = {
            {
                ' ⟵ ' .. info,
                'DiagnosticHint',
            },
        },
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
M.setup = function(opts)
    opts = opts or {}
    if opts.incremental_selection ~= false then
        vim.keymap.set('x', 'g-', dec_node, {
            desc = 'TS select child',
        })
        vim.keymap.set('x', 'gN', inc_parent, {
            desc = 'TS select parent',
        })
        vim.keymap.set('x', 'gn', inc_node, {
            desc = 'TS select node',
        })
    end
    if opts.textobjects ~= false then
        vim.keymap.set(
            {
                'x',
                'o',
            },
            'af',
            function()
                select_around('function_declaration')
            end,
            { desc = 'around function (TS)' }
        )
        vim.keymap.set(
            {
                'x',
                'o',
            },
            'if',
            select_inner_function,
            {
                desc = 'inner function (TS)',
            }
        )
    end
    if opts.context ~= false then
        setup_context_provider()
    end
    if opts.end_labels ~= false then
        setup_end_labels_autocmd()
        vim.api.nvim_create_user_command('DecorEndLabelsToggle', function(command)
            toggle_end_labels(command.bang)
        end, {
            bang = true,
            desc = 'Toggle TS end-of-block labels (buffer; ! toggles the global default)',
            force = true,
        })
        vim.keymap.set('n', '<leader>te', function()
            toggle_end_labels(false)
        end, {
            desc = 'TS end labels toggle',
        })
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
