-- highlight.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

---@class vim.qf.TSHighlight
---@field [1] integer start_col
---@field [2] integer end_col
---@field [3] string highlight group
---@class vim.qf.FileCache
---@field private count_per_buf table<number, number>
---@field private max_line_per_buf table<number, number>
---@field private cache table<number, string[]>
---@class (exact) vim.qf.ParsedLine
---@field filename? string
---@field lnum? integer
---@field text? string
---@class (exact) vim.qf.QuickFixUserData
---@field header? "hard"|"soft" When present, this line is a header
---@field lnum? integer Encode the lnum separately for valid=0 items
---@field error_text? string
---@class (exact) vim.qf.QuickFixItem
---@field text string
---@field type string
---@field lnum integer line number in the buffer (first line is 1)
---@field end_lnum integer end of line number if the item is multiline
---@field col integer column number (first column is 1)
---@field end_col integer end of column number if the item has range
---@field vcol 0|1 if true "col" is visual column. If false "col" is byte index
---@field nr integer error number
---@field pattern string search pattern used to locate the error
---@field bufnr integer number of buffer that has the file name
---@field module string
---@field valid 0|1
---@field user_data? any
---@class (exact) vim.qf.QFContext
---@field num_before integer
---@field num_after integer
---@class (exact) vim.qf.ExpandOpts
---@field before? integer Number of lines of context to show before the line (default 2)
---@field after? integer Number of lines of context to show after the line (default 2)
---@field add_to_existing? boolean
---@field loclist_win? integer
---@alias vim.qf.TrimEnum "all"|"common"|false
---@class vim.qf..Config
---@field on_qf fun(bufnr: number)
---@field opts table<string, any>
----@field keys vim.qf.Keymap[]
---@field use_default_opts boolean
---@field constrain_cursor boolean
---@field highlight vim.qf.HighlightConfig
---@field follow vim.qf.FollowConfig
---@field edit vim.qf.EditConfig
---@field type_icons table<string, string>
---@field borders vim.qf.Borders
---@field trim_leading_whitespace vim.qf.TrimEnum
---@field max_filename_width fun(): integer
---@field header_length fun(type: "hard"|"soft", start_col: integer): integer
---@class (exact) vim.qf.SetupOptions
---@field on_qf? fun(bufnr: number) Callback function to run any custom logic or keymaps for the quickfix buffer
---@field opts? table<string, any> Local options to set for quickfix
----@field keys? vim.qf.Keymap[] Keymaps to set for the quickfix buffer
---@field use_default_opts? boolean Set to false to disable the default options in `opts`
---@field constrain_cursor? boolean Keep the cursor to the right of the filename and lnum columns
---@field highlight? vim.qf.SetupHighlightConfig Configure syntax highlighting
---@field follow? vim.qf.SetupFollowConfig Configure cursor following
---@field edit? vim.qf.SetupEditConfig
---@field type_icons? table<string, string> Map of quickfix item type to icon
---@field borders? vim.qf.SetupBorders Characters used for drawing the borders
---@field trim_leading_whitespace? vim.qf.TrimEnum How to trim the leading whitespace from results
---@field max_filename_width? fun(): integer Maximum width of the filename column
---@field header_length? fun(type: "hard"|"soft", start_col: integer): integer How far the header should extend to the right
--@class (exact) quicker.Keymap
---@field [1] string Key sequence
---@field [2] any Command to run
---@field desc? string
---@field mode? string
---@field expr? boolean
---@field nowait? boolean
---@field remap? boolean
---@field replace_keycodes? boolean
---@field silent? boolean
---@class vim.qf.LSPHighlight
---@field [1] integer start_col
---@field [2] integer end_col
---@field [3] string highlight group
---@field [4] integer priority modifier
---@class (exact) vim.qf.Borders
---@field vert string
---@field strong_header string
---@field strong_cross string
---@field strong_end string
---@field soft_header string
---@field soft_cross string
---@field soft_end string

---@class (exact) vim.qf.SetupBorders
---@field vert? string
---@field strong_header? string Strong headers separate results from different files
---@field strong_cross? string
---@field strong_end? string
---@field soft_header? string Soft headers separate results within the same file
---@field soft_cross? string
---@field soft_end? string

---@class (exact) vim.qf.HighlightConfig
---@field treesitter boolean
---@field lsp boolean
---@field load_buffers boolean

---@class (exact) vim.qf.SetupHighlightConfig
---@field treesitter? boolean Enable treesitter syntax highlighting
---@field lsp? boolean Use LSP semantic token highlighting
---@field load_buffers? boolean Load the referenced buffers to apply more accurate highlights (may be slow)

---@class (exact) vim.qf.FollowConfig
---@field enabled boolean

---@class (exact) vim.qf.SetupFollowConfig
---@field enabled? boolean

---@class (exact) vim.qf.EditConfig
---@field enabled boolean
---@field autosave boolean|"unmodified"

---@class (exact) vim.qf.SetupEditConfig
---@field enabled? boolean
---@field autosave? boolean|"unmodified"

local _cached_queries = {}
---@param lang string
---@return vim.treesitter.Query?
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

    local highlights = {}
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
    local ft = vim.bo[bufnr].filetype
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
                table.insert(
                    lsp_highlights,
                    { token.start_col, token.end_col, string.format('@lsp.type.%s.%s', token.type, ft), 0 }
                )
                for modifier, _ in pairs(token.modifiers) do
                    table.insert(
                        lsp_highlights,
                        { token.start_col, token.end_col, string.format('@lsp.mod.%s.%s', modifier, ft), 1 }
                    )
                    table.insert(lsp_highlights, {
                        token.start_col,
                        token.end_col,
                        string.format('@lsp.typemod.%s.%s.%s', token.type, modifier, ft),
                        2,
                    })
                end
            end
        end
    end

    return lsp_highlights
end

----@param item QuickFixItem
----@param line string
----@return vim.qf.TSHighlight[]
M.get_heuristic_ts_highlights = function(item, line)
    local filetype = vim.filetype.match({ buf = item.bufnr })
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

    local highlights = {}
    for capture, node, metadata in query:iter_captures(root, line) do
        if capture == nil then
            break
        end

        local range = vim.treesitter.get_range(node, line, metadata[capture])
        local start_row, start_col, _, end_row, end_col, _ = unpack(range)
        local capture_name = query.captures[capture]
        local hl = string.format('@%s.%s', capture_name, lang)
        if end_row > start_row then
            end_col = -1
        end
        table.insert(highlights, { start_col, end_col, hl })
    end

    return highlights
end

function M.set_highlight_groups()
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixHeaderHard' })) then
        vim.api.nvim_set_hl(0, 'QuickFixHeaderHard', { link = 'Delimiter', default = true })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixHeaderSoft' })) then
        vim.api.nvim_set_hl(0, 'QuickFixHeaderSoft', { link = 'Comment', default = true })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixFilename' })) then
        vim.api.nvim_set_hl(0, 'QuickFixFilename', { link = 'Directory', default = true })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixFilenameInvalid' })) then
        vim.api.nvim_set_hl(0, 'QuickFixFilenameInvalid', { link = 'Comment', default = true })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixLineNr' })) then
        vim.api.nvim_set_hl(0, 'QuickFixLineNr', { link = 'LineNr', default = true })
    end
    if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = 'QuickFixTextInvalid' })) then
        vim.api.nvim_set_hl(0, 'QuickFixTextInvalid', { link = 'QuickFixText', default = true })
    end
end

return M
