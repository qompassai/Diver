-- #################################################################
-- /qompassai/Diver/lua/refactor/core.lua
-- Native Neovim 0.13+ refactor core
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

local api = vim.api
local ts = vim.treesitter

local M = {}

local TREE_DEPTH_MAX = 64
local SELECTION_BYTES_MAX = 1024 * 1024

---@class refactor.NativeRange
---@field start [integer, integer]
---@field ["end"] [integer, integer]

---@param message string
---@param level? integer
function M.notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, {
        title = 'Native Refactor',
    })
end

---@return nil
function M.require_nvim_013()
    if vim.fn.has('nvim-0.13') ~= 1 then
        error('native refactor requires Neovim >= 0.13', 2)
    end

    assert(vim.range ~= nil, 'Neovim 0.13 vim.range API is required')
    assert(vim.pos ~= nil, 'Neovim 0.13 vim.pos API is required')
end

---@param bufnr? integer
---@return integer
function M.bufnr(bufnr)
    local buf = bufnr or api.nvim_get_current_buf()
    assert(type(buf) == 'number')
    assert(api.nvim_buf_is_valid(buf), 'invalid buffer')
    return buf
end

---@param bufnr integer
---@return refactor.NativeRange?
function M.visual_lsp_range(bufnr)
    local start_mark = api.nvim_buf_get_mark(bufnr, '<')
    local end_mark = api.nvim_buf_get_mark(bufnr, '>')

    if start_mark[1] == 0 or end_mark[1] == 0 then
        return nil
    end

    return {
        start = { start_mark[1], start_mark[2] },
        ['end'] = { end_mark[1], end_mark[2] },
    }
end

---@param bufnr integer
---@return vim.Range?
function M.visual_range(bufnr)
    local start_mark = api.nvim_buf_get_mark(bufnr, '<')
    local end_mark = api.nvim_buf_get_mark(bufnr, '>')

    if start_mark[1] == 0 or end_mark[1] == 0 then
        return nil
    end

    return vim.range.mark(bufnr, start_mark[1], start_mark[2], end_mark[1], end_mark[2])
end

---@param bufnr integer
---@param line1 integer
---@param line2 integer
---@return vim.Range
function M.line_range(bufnr, line1, line2)
    assert(line1 >= 1)
    assert(line2 >= line1)

    local last = api.nvim_buf_get_lines(bufnr, line2 - 1, line2, true)[1] or ''
    return vim.range(bufnr, line1 - 1, 0, line2 - 1, #last)
end

---@param bufnr integer
---@return vim.Range
function M.cursor_range(bufnr)
    local cursor = api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    return vim.range(bufnr, row, col, row, col)
end

---@param range vim.Range
---@return string
function M.range_text(range)
    local srow, scol, erow, ecol = range:to_extmark()
    local lines = api.nvim_buf_get_text(range.buf, srow, scol, erow, ecol, {})
    local text = table.concat(lines, '\n')

    if #text > SELECTION_BYTES_MAX then
        error(('selection exceeds %d bytes'):format(SELECTION_BYTES_MAX), 2)
    end

    return text
end

---@param bufnr integer
---@param row integer
---@return string
function M.indent_at(bufnr, row)
    local line = api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1] or ''
    return line:match('^%s*') or ''
end

---@param bufnr integer
---@param row integer
---@param lines string[]
---@return nil
function M.insert_lines(bufnr, row, lines)
    assert(row >= 0)
    assert(type(lines) == 'table')
    api.nvim_buf_set_lines(bufnr, row, row, true, lines)
end

---@param bufnr integer
---@param range vim.Range
---@return vim.treesitter.LanguageTree?, string?
function M.language_tree(bufnr, range)
    local parser, err = ts.get_parser(bufnr, nil, { error = false })
    if not parser then
        return nil, err or 'no Tree-sitter parser'
    end

    local srow, scol, erow, ecol = range:to_extmark()
    parser:parse({ srow, math.max(srow + 1, erow + 1) })

    local tree = parser:language_for_range({ srow, scol, erow, ecol })
    return tree, nil
end

---@param bufnr integer
---@param range vim.Range
---@return TSNode?
function M.node_at_range(bufnr, range)
    local parser = ts.get_parser(bufnr, nil, { error = false })
    if not parser then
        return nil
    end

    local srow, scol, erow, ecol = range:to_extmark()
    parser:parse({ srow, math.max(srow + 1, erow + 1) })

    return parser:named_node_for_range({ srow, scol, erow, ecol }, { ignore_injections = false })
end

local STATEMENT_TYPES = {
    assignment = true,
    call = true,
    declaration = true,
    expression_statement = true,
    return_statement = true,
    throw_statement = true,
    break_statement = true,
    continue_statement = true,
}

---@param node TSNode
---@return boolean
local function is_statement(node)
    local kind = node:type()

    if STATEMENT_TYPES[kind] then
        return true
    end

    if kind:find('statement', 1, true) then
        return true
    end

    if kind:find('declaration', 1, true) then
        return true
    end

    return false
end

---@param bufnr integer
---@param range vim.Range
---@return vim.Range
function M.statement_range(bufnr, range)
    local node = M.node_at_range(bufnr, range)
    local depth = 0

    while node and depth < TREE_DEPTH_MAX do
        if is_statement(node) then
            local srow, scol, erow, ecol = node:range()
            local candidate = vim.range(bufnr, srow, scol, erow, ecol)

            local contains = candidate:has(range)
            if range:is_empty() then
                contains = candidate:has(vim.pos(bufnr, range.start_row, range.start_col))
            end

            if contains then
                return candidate
            end
        end

        node = node:parent()
        depth = depth + 1
    end

    local srow = range.start_row
    local line = api.nvim_buf_get_lines(bufnr, srow, srow + 1, true)[1] or ''
    return vim.range(bufnr, srow, 0, srow, #line)
end

local PATH_NODE_NAMES = {
    { 'if', 'if' },
    { 'for', 'for' },
    { 'while', 'while' },
    { 'loop', 'loop' },
    { 'match', 'match' },
    { 'switch', 'switch' },
    { 'try', 'try' },
    { 'catch', 'catch' },
    { 'class', 'class' },
    { 'struct', 'struct' },
    { 'impl', 'impl' },
}

---@param node TSNode
---@return string? label
---@return TSNode? name
local function structural_name(node)
    local kind = node:type()
    local lower = kind:lower()

    if lower:find('function', 1, true) or lower:find('method', 1, true) then
        local name = node:child_by_field_name('name')
        if name then
            return nil, name
        end
        return 'function', nil
    end

    for _, item in ipairs(PATH_NODE_NAMES) do
        if lower:find(item[1], 1, true) then
            return item[2], nil
        end
    end

    return nil, nil
end

---@param bufnr integer
---@param range vim.Range
---@return string
function M.debug_path(bufnr, range)
    local filename = vim.fs.basename(api.nvim_buf_get_name(bufnr))
    if filename == '' then
        filename = '[No Name]'
    end

    local segments = { filename }
    local node = M.node_at_range(bufnr, range)
    local pending_names = {}
    local depth = 0

    while node and depth < TREE_DEPTH_MAX do
        local label, name_node = structural_name(node)

        if name_node then
            local text = ts.get_node_text(name_node, bufnr)
            if text ~= '' then
                table.insert(pending_names, text)
            end
        elseif label then
            table.insert(pending_names, label)
        end

        node = node:parent()
        depth = depth + 1
    end

    for index = #pending_names, 1, -1 do
        table.insert(segments, pending_names[index])
    end

    return table.concat(segments, '#')
end

---@param bufnr integer
---@param range vim.Range
---@return string
function M.language(bufnr, range)
    local tree = M.language_tree(bufnr, range)
    if tree then
        return tree:lang()
    end

    return vim.bo[bufnr].filetype
end

---@param bufnr integer
---@param range vim.Range
---@return string?
function M.commentstring(bufnr, range)
    local lang = M.language(bufnr, range)

    if lang ~= '' then
        local ok, filetypes = pcall(ts.language.get_filetypes, lang)
        if ok then
            for _, filetype in ipairs(filetypes) do
                local value = vim.filetype.get_option(filetype, 'commentstring')
                if type(value) == 'string' and value:find('%%s') then
                    return value
                end
            end
        end
    end

    local value = vim.bo[bufnr].commentstring
    if value ~= '' and value:find('%%s') then
        return value
    end

    return nil
end

---@param commentstring string
---@param text string
---@return string
function M.comment(commentstring, text)
    assert(commentstring:find('%%s'))
    return (commentstring:gsub('%%s', text, 1))
end

return M
