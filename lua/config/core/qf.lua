-- /qompassai/Diver/lua/config/core/qf.lua
-- Qompass AI Diver Core QuickFix Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local _cached_queries = {}
local function get_highlight_query(lang)
    local query = _cached_queries[lang]
    if query == nil then
        query = vim.treesitter.query.get(lang, 'highlights') or false
        _cached_queries[lang] = query
    end
    if query then
        return query
    end
end
---@param bufnr integer
---@param lnum integer
---@return vim.qf.TSHighlight[]
function M.buf_get_ts_highlights(bufnr, lnum)
    local filetype = vim.bo[bufnr].filetype
    if not filetype or filetype == '' then
        filetype = vim.filetype.match({ buf = bufnr }) or ''
    end
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    if lang == '' then
        return {}
    end
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
    if not ok or not parser then
        return {}
    end
    local row = lnum - 1
    if not parser:is_valid() then
        parser:parse(true)
    end
    local highlights = {} ---@type vim.qf.TSHighlight[]
    parser:for_each_tree(function(tstree, tree)
        if not tstree then
            return
        end
        local root_node = tstree:root()
        local root_start_row, _, root_end_row, _ = root_node:range()
        if root_start_row > row or root_end_row < row then
            return
        end
        local query = get_highlight_query(tree:lang())
        if not query then
            return
        end
        for capture, node, metadata in query:iter_captures(root_node, bufnr, row, root_end_row + 1) do
            if capture == nil then
                break
            end
            local range = vim.treesitter.get_range(node, bufnr, metadata[capture])
            local start_row, start_col, _, end_row, end_col, _ = unpack(range)
            if start_row > row then
                break
            end
            local capture_name = query.captures[capture]
            local hl = string.format('@%s.%s', capture_name, tree:lang())
            if end_row > start_row then
                end_col = -1
            end
            table.insert(highlights, { start_col, end_col, hl })
        end
    end)
    return highlights
end

local STHighlighter = vim.lsp.semantic_tokens.__STHighlighter
---@private
local function lower_bound(tokens, line, lo, hi)
    while lo < hi do
        local mid = bit.rshift(lo + hi, 1)
        if tokens[mid].line < line then
            lo = mid + 1
        else
            hi = mid
        end
    end
    return lo
end
---@param bufnr integer
---@param lnum integer
---@return vim.qf.LSPHighlight[]
function M.buf_get_lsp_highlights(bufnr, lnum)
    local highlighter = STHighlighter.active[bufnr]
    if not highlighter then
        return {}
    end
    local lsp_highlights = {}
    for _, client in pairs(highlighter.client_state) do
        local highlights = client.current_result.highlights
        if highlights then
            local idx = lower_bound(highlights, lnum - 1, 1, #highlights + 1)
            for i = idx, #highlights do
                local token = highlights[i]
                if token.line >= lnum then
                    break
                end
                table.insert(lsp_highlights, {
                    token.start_col,
                    token.end_col,
                    string.format('@lsp.type.%s.%s', token.type, vim.bo[bufnr].filetype),
                    0,
                })
                for modifier, _ in pairs(token.modifiers) do
                    table.insert(lsp_highlights, {
                        token.start_col,
                        token.end_col,
                        string.format('@lsp.mod.%s.%s', modifier, vim.bo[bufnr].filetype),
                        1,
                    })
                    table.insert(lsp_highlights, {
                        token.start_col,
                        token.end_col,
                        string.format('@lsp.typemod.%s.%s.%s', token.type, modifier, vim.bo[bufnr].filetype),
                        2,
                    })
                end
            end
        end
    end
    return lsp_highlights
end

---@param item vim.qf.QuickFixItem
---@param line string
---@return vim.qf.TSHighlight[]
M.get_heuristic_ts_highlights = function(item, line)
    local filetype = vim.filetype.match({
        buf = item.bufnr,
    })
    if not filetype then
        return {}
    end
    local lang = vim.treesitter.language.get_lang(filetype)
    if not lang then
        return {}
    end
    local has_parser, parser = pcall(vim.treesitter.get_string_parser, line, lang)
    if not has_parser then
        return {}
    end
    local root = parser:parse(true)[1]:root()
    local query = vim.treesitter.query.get(lang, 'highlights')
    if not query then
        return {}
    end
    local highlights = {} ---@type vim.qf.TSHighlight[]
    for capture, node, metadata in query:iter_captures(root, line) do
        if capture == nil then
            break
        end
        local range = vim.treesitter.get_range(node, line, metadata[capture])
        local start_row, ---@type integer
            start_col, ---@type integer
            _, ---@type integer
            end_row, ---@type integer
            end_col, ---@type integer
            _ =
            unpack(range)
        local capture_name = query.captures[capture]
        local hl = string.format('@%s.%s', capture_name, lang)
        if end_row > start_row then
            end_col = -1 ---@type integer
        end
        table.insert(highlights, {
            start_col,
            end_col,
            hl,
        })
    end
    return highlights
end
function M.set_highlight_groups()
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixHeaderHard',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixHeaderHard', {
            link = 'Delimiter',
            default = true,
        })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixHeaderSoft',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixHeaderSoft', {
            link = 'Comment',
            default = true,
        })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixFilename',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixFilename', {
            link = 'Directory',
            default = true,
        })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixFilenameInvalid',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixFilenameInvalid', {
            link = 'Comment',
            default = true,
        })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixLineNr',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixLineNr', {
            link = 'LineNr',
            default = true,
        })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, {
        name = 'QuickFixTextInvalid',
    })) then
        vim.api.nvim_set_hl(0, 'QuickFixTextInvalid', {
            link = 'QuickFixText',
            default = true,
        })
    end
end

return M