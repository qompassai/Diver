--- Table toggle: expand or collapse the table constructor at the
--- cursor, one field per line or joined onto a single line.
---
--- Plain-language version: some tables read better as a vertical list
--- (one field per line - changing a value is then a one-line edit and
--- a one-line diff), others as a compact one-liner. StyLua never
--- re-collapses a table that spans lines in the source, and never
--- expands one that fits the column width, so the shape is whatever
--- the author left. This helper flips the shape deliberately, at the
--- cursor, and both of its end states are shapes StyLua preserves.
---
--- Contract (refusals are explicit, never partial rewrites):
---   * The target is the nearest table constructor containing the
---     cursor (treesitter), so nested tables toggle at the level the
---     cursor is in. When the cursor is not inside any table, the
---     nearest table in the buffer is the target instead - smallest
---     line distance, ties to the table at or above the cursor, then
---     outermost - and the toggle says which line it acted on.
---   * Every direct field must be a single line of source. A field
---     that itself spans lines (a nested expanded table, a function)
---     refuses the toggle; toggle the inner table instead.
---   * A line comment anywhere inside the constructor refuses the
---     toggle; comments have no safe mechanical home in the other
---     shape. Block comments are content: they keep their field
---     multi-line or single-line like any other text.
---   * Collapsing also refuses when the joined line would exceed the
---     StyLua column width (120, mirrored from lsp/stylua_ls.lua).
---   * With auto_expand_on_save, the toggle registers a formatters
---     pipeline stage (priority 100, ahead of the format stages)
---     that expands every eligible single-line constructor in the
---     buffer before writing (never collapses, never touches
---     multi-line shapes or shapes the planner refuses, e.g. empty
---     constructors). All expansions in one save join a single undo
---     step. The pass is governed by vim.g.table_toggle_auto_expand
---     and, per buffer, vim.b.table_toggle_auto_expand (false
---     disables); the :TableToggleAuto command flips the global flag.
---@module 'utils.table_toggle'
-- /qompassai/Diver/lua/utils/table_toggle.lua
-- Qompass AI Diver Table Toggle
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------

local api = vim.api

local M = {}

--- True once setup() has registered the save pipeline stage.
local stage_registered = false

--- Column width ceiling for a collapsed line. Mirrors the canonical
--- value in lsp/stylua_ls.lua (the StyLua single source of truth).
local COLUMN_WIDTH_MAX = 120
--- Largest constructor text, in bytes, the toggle will rewrite.
local CONSTRUCTOR_BYTES_MAX = 65536
--- Most constructors the fallback search will consider.
local CONSTRUCTORS_MAX = 2048
--- Most constructors one auto-expand save pass will rewrite.
local EXPAND_PASSES_MAX = 1024
--- Most direct fields one toggle will move.
local FIELD_COUNT_MAX = 512
--- One indent level in expanded output: four spaces, mirroring
--- indent_width in lsp/stylua_ls.lua. The formatter's value governs
--- (not the buffer shiftwidth) so toggle output is StyLua-stable.
local INDENT = '    '
--- Most treesitter nodes the fallback search will visit.
local VISITED_NODES_MAX = 65536

--- Scan state for the field splitter. Strings and long brackets are
--- opaque: brackets and commas inside them do not count. `skip_bytes`
--- carries the unconsumed remainder of a long bracket opener/closer
--- so its later bytes are never re-read as fresh brackets.
---@class TableToggleScan
---@field depth integer bracket depth relative to the constructor
---@field long_bracket_level integer|nil level of an open long bracket
---@field quote string|nil the open quote character, if any
---@field escaped boolean previous byte was a backslash in a string
---@field skip_bytes integer bytes of a bracket delimiter to skip

--- Advance the scan state by one byte of constructor inner text.
---@param state TableToggleScan
---@param text string
---@param index integer byte index of the current character
---@return boolean starts_comment true when this byte opens a line comment
local function scan_step(state, text, index)
    if state.skip_bytes > 0 then
        state.skip_bytes = state.skip_bytes - 1
        return false
    end
    local char = text:sub(index, index)
    if state.long_bracket_level then
        local closer = ']' .. ('='):rep(state.long_bracket_level) .. ']'
        if text:sub(index, index + #closer - 1) == closer then
            state.long_bracket_level = nil
            state.skip_bytes = #closer - 1
        end
        return false
    end
    if state.quote then
        if state.escaped then
            state.escaped = false
        elseif char == '\\' then
            state.escaped = true
        elseif char == state.quote then
            state.quote = nil
        end
        return false
    end
    if char == '-' and text:sub(index + 1, index + 1) == '-' then
        local equals = text:match('^%[(=*)%[', index + 2)
        if equals then
            -- A long comment is an opaque long bracket.
            state.long_bracket_level = #equals
            state.skip_bytes = #equals + 3
            return false
        end
        return true
    end
    if char == '"' or char == "'" then
        state.quote = char
        return false
    end
    if char == '[' then
        local equals = text:match('^%[(=*)%[', index)
        if equals then
            state.long_bracket_level = #equals
            state.skip_bytes = #equals + 1
            return false
        end
        state.depth = state.depth + 1
        return false
    end
    if char == '{' or char == '(' then
        state.depth = state.depth + 1
    elseif char == '}' or char == ')' or char == ']' then
        state.depth = state.depth - 1
    end
    return false
end

---@return TableToggleScan
local function new_scan()
    return { depth = 0, escaped = false, skip_bytes = 0 }
end

--- Whether the inner text contains a line comment outside strings.
---@param inner string constructor text between the braces
---@return boolean
local function has_line_comment(inner)
    local state = new_scan()
    for index = 1, #inner do
        if scan_step(state, inner, index) then
            return true
        end
    end
    return false
end

--- Split constructor inner text at top-level commas.
---@param inner string constructor text between the braces
---@return string[]|nil fields trimmed field texts, in source order
---@return string|nil error descriptive error when the text is unusable
---@return boolean tail_newline newline follows the last field (or the
--- last comma, when the final segment is empty)
local function split_fields(inner)
    local state = new_scan()
    local fields = {}
    local segment_start = 1
    for index = 1, #inner do
        local char = inner:sub(index, index)
        if scan_step(state, inner, index) then
            return nil, 'constructor contains a comment', false
        end
        if char == ',' and state.depth == 0 and not state.quote and not state.long_bracket_level then
            local trimmed = inner:sub(segment_start, index - 1):match('^%s*(.-)%s*$')
            if trimmed ~= '' then
                fields[#fields + 1] = trimmed
                if #fields > FIELD_COUNT_MAX then
                    return nil, 'constructor has too many fields', false
                end
            end
            segment_start = index + 1
        end
    end
    local tail = inner:sub(segment_start)
    local tail_trimmed = tail:match('^%s*(.-)%s*$')
    if tail_trimmed ~= '' then
        fields[#fields + 1] = tail_trimmed
        return fields, nil, false
    end
    return fields, nil, tail:find('\n') ~= nil
end

--- Build the expanded replacement lines for a constructor.
---@param prefix string start line text through the opening brace
---@param suffix string end line text after the closing brace
---@param fields string[] single-line field texts
---@param base_indent string indentation of the constructor's first line
---@param indent string one indent level
---@return string[] lines
local function expand_lines(prefix, suffix, fields, base_indent, indent)
    local lines = { prefix }
    for _, field in ipairs(fields) do
        lines[#lines + 1] = base_indent .. indent .. field .. ','
    end
    lines[#lines + 1] = base_indent .. '}' .. suffix
    return lines
end

--- Build the collapsed replacement line, or refuse.
---@param prefix string start line text through the opening brace
---@param suffix string end line text after the closing brace
---@param fields string[] single-line field texts
---@return string|nil line
---@return string|nil error
local function collapse_line(prefix, suffix, fields)
    local joined = prefix .. ' ' .. table.concat(fields, ', ') .. ' }' .. suffix
    if #joined > COLUMN_WIDTH_MAX then
        return nil, 'collapsed line would exceed ' .. COLUMN_WIDTH_MAX .. ' columns'
    end
    return joined, nil
end

--- Plan a toggle over raw constructor parts. Pure: no editor state.
--- Direction: a single-line constructor expands; a multi-line one
--- whose last field is followed by a newline (the expanded shape)
--- collapses; any other multi-line shape normalizes to expanded.
---@param prefix string start line text through the opening brace
---@param inner string constructor text between the braces
---@param suffix string end line text after the closing brace
---@param base_indent string indentation of the constructor's first line
---@param indent string one indent level
---@return string[]|nil lines replacement lines for the constructor range
---@return string|nil error descriptive refusal, when no rewrite is safe
local function plan(prefix, inner, suffix, base_indent, indent)
    if #inner > CONSTRUCTOR_BYTES_MAX then
        return nil, 'constructor is too large to toggle safely'
    end
    if has_line_comment(inner) then
        return nil, 'constructor contains a comment'
    end
    local fields, err, tail_newline = split_fields(inner)
    if not fields then
        return nil, err
    end
    if #fields == 0 then
        return nil, 'constructor is empty'
    end
    for _, field in ipairs(fields) do
        if field:find('\n') then
            return nil, 'a field spans multiple lines; toggle the inner table instead'
        end
    end
    if not inner:find('\n') then
        return expand_lines(prefix, suffix, fields, base_indent, indent), nil
    end
    if tail_newline then
        local line, collapse_err = collapse_line(prefix, suffix, fields)
        if not line then
            return nil, collapse_err
        end
        return { line }, nil
    end
    return expand_lines(prefix, suffix, fields, base_indent, indent), nil
end

--- Find the nearest table constructor at or above a treesitter node.
---@param node TSNode? starting node
---@return TSNode? node the table_constructor node, if any
local function find_constructor(node)
    local current = node
    while current do
        if current:type() == 'table_constructor' then
            return current
        end
        current = current:parent()
    end
    return nil
end

--- Collect every table constructor under a root, bounded both in
--- nodes visited and constructors kept. Traversal order is source
--- order for equal keys only by accident; callers must not rely on
--- it (pick_fallback compares explicit keys).
---@param root TSNode
---@return TSNode[] constructors
local function collect_constructors(root)
    local found = {}
    local stack = { root }
    local visited = 0
    while #stack > 0 and visited < VISITED_NODES_MAX do
        local node = stack[#stack]
        stack[#stack] = nil
        visited = visited + 1
        if node:type() == 'table_constructor' then
            found[#found + 1] = node
            if #found >= CONSTRUCTORS_MAX then
                break
            end
        end
        local child_count = node:named_child_count()
        for index = child_count - 1, 0, -1 do
            local child = node:named_child(index)
            if child then
                stack[#stack + 1] = child
            end
        end
    end
    return found
end

--- Whole lines between a row and a node's row span: 0 when the span
--- covers the row, else the gap to the nearest edge.
---@param node TSNode
---@param row integer 0-based row
---@return integer distance
local function line_distance(node, row)
    local start_row, _, end_row = node:range()
    if row < start_row then
        return start_row - row
    end
    if row > end_row then
        return row - end_row
    end
    return 0
end

--- Lexicographic less-than over small numeric key arrays.
---@param a integer[]
---@param b integer[]
---@return boolean
local function key_less(a, b)
    for index = 1, #a do
        if a[index] ~= b[index] then
            return a[index] < b[index]
        end
    end
    return false
end

--- Pick the fallback constructor for a cursor row: smallest line
--- distance wins; ties go to a table starting at or above the row,
--- then to the outermost table (earliest start, latest end).
---@param constructors TSNode[]
---@param row integer 0-based cursor row
---@return TSNode? node
local function pick_fallback(constructors, row)
    local best = nil
    local best_key = nil
    for _, node in ipairs(constructors) do
        local start_row, start_col, end_row, end_col = node:range()
        local at_or_above = start_row <= row and 0 or 1
        local key = { line_distance(node, row), at_or_above, start_row, start_col, -end_row, -end_col }
        if not best_key or key_less(key, best_key) then
            best = node
            best_key = key
        end
    end
    return best
end

--- Parse a buffer fresh and return the tree root. Freshness is a
--- correctness requirement, not a preference: vim.treesitter.get_node
--- reads a cached tree that lags behind buffer edits, and a stale
--- range applied to current text would rewrite the wrong lines.
---@param bufnr integer
---@return TSNode? root
---@return string|nil error
local function parse_root(bufnr)
    local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, 'lua')
    if not ok_parser or not parser then
        return nil, 'no Lua treesitter parser for this buffer'
    end
    local trees = parser:parse()
    if not trees or not trees[1] then
        return nil, 'treesitter parse failed'
    end
    return trees[1]:root(), nil
end

---@class TableToggleEvaluation
---@field end_row integer 0-based last row of the constructor
---@field replacement string[] planned replacement lines
---@field start_col integer 0-based byte column of the opening brace
---@field start_row integer 0-based first row of the constructor

--- Evaluate one constructor against the buffer's current text: run
--- the pure planner and package the rewrite, without applying it.
---@param bufnr integer
---@param constructor TSNode
---@return TableToggleEvaluation|nil evaluation
---@return string|nil error descriptive refusal, when no rewrite is safe
local function evaluate(bufnr, constructor)
    local start_row, start_col, end_row, end_col = constructor:range()
    local lines = api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
    local text = vim.treesitter.get_node_text(constructor, bufnr)
    if text:sub(1, 1) ~= '{' or text:sub(-1) ~= '}' then
        return nil, 'treesitter range mismatch; nothing changed'
    end
    local inner = text:sub(2, -2)
    local prefix = lines[1]:sub(1, start_col) .. '{'
    local suffix = lines[#lines]:sub(end_col + 1)
    local base_indent = lines[1]:match('^%s*') or ''
    local replacement, err = plan(prefix, inner, suffix, base_indent, INDENT)
    if not replacement then
        return nil, err
    end
    return { end_row = end_row, replacement = replacement, start_col = start_col, start_row = start_row }, nil
end

--- Apply a packaged rewrite to the buffer.
---@param bufnr integer
---@param evaluation TableToggleEvaluation
---@param join_undo boolean join the previous undo step (save passes)
local function apply_evaluation(bufnr, evaluation, join_undo)
    if join_undo then
        pcall(vim.cmd, 'undojoin')
    end
    api.nvim_buf_set_lines(bufnr, evaluation.start_row, evaluation.end_row + 1, false, evaluation.replacement)
end

--- Toggle the shape of the table constructor at the cursor, or of
--- the nearest constructor when the cursor is inside none.
---@return boolean ok true when the buffer was rewritten
---@return string|nil detail on success, the line acted on when the
--- fallback chose the target; on failure, the refusal reason
local function toggle_at_cursor()
    local bufnr = api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype ~= 'lua' then
        return false, 'table toggle only applies to Lua buffers'
    end
    local root, parse_err = parse_root(bufnr)
    if not root then
        return false, parse_err
    end
    -- A cursor resting exactly on a brace byte sits on the boundary
    -- between the constructor and its parent. Probe the cursor byte,
    -- then one byte to either side, first hit inside a constructor.
    local cursor = api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local probes = { cursor[2], cursor[2] + 1, cursor[2] - 1 }
    local constructor = nil
    for _, col in ipairs(probes) do
        if col >= 0 then
            local node = root:named_descendant_for_range(row, col, row, col)
            if node then
                constructor = find_constructor(node)
                if constructor then
                    break
                end
            end
        end
    end
    local via_fallback = false
    if not constructor then
        local all = collect_constructors(root)
        if #all == 0 then
            return false, 'no table in this buffer'
        end
        constructor = pick_fallback(all, row)
        if not constructor then
            return false, 'no table in this buffer'
        end
        via_fallback = true
    end
    local evaluation, err = evaluate(bufnr, constructor)
    if not evaluation then
        return false, err
    end
    apply_evaluation(bufnr, evaluation, false)
    api.nvim_win_set_cursor(0, { evaluation.start_row + 1, evaluation.start_col })
    if via_fallback then
        return true, 'acted on line ' .. (evaluation.start_row + 1)
    end
    return true, nil
end

--- Expand every eligible single-line constructor in a buffer, one
--- fresh parse per rewrite so ranges never go stale. A constructor
--- is eligible when it sits on one row and the planner expands it;
--- empty constructors and other planner refusals are skipped, and
--- multi-line shapes are never touched. Returns the count expanded.
---@param bufnr integer
---@return integer changed constructors expanded by this pass
local function expand_buffer(bufnr)
    if vim.bo[bufnr].filetype ~= 'lua' or vim.bo[bufnr].buftype ~= '' then
        return 0
    end
    if vim.b[bufnr].table_toggle_auto_expand == false or vim.g.table_toggle_auto_expand == false then
        return 0
    end
    local changed = 0
    for _ = 1, EXPAND_PASSES_MAX do
        local root = parse_root(bufnr)
        if not root then
            break
        end
        local best_key = nil
        local best_eval = nil
        for _, node in ipairs(collect_constructors(root)) do
            local start_row, start_col, end_row = node:range()
            if start_row == end_row then
                local key = { start_row, start_col }
                if not best_key or key_less(key, best_key) then
                    local evaluation = evaluate(bufnr, node)
                    if evaluation then
                        best_key = key
                        best_eval = evaluation
                    end
                end
            end
        end
        if not best_eval then
            break
        end
        apply_evaluation(bufnr, best_eval, changed > 0)
        changed = changed + 1
    end
    return changed
end

--- Save-stage body: expand, then restore the window view the extra
--- lines would otherwise push around.
---@param bufnr integer
local function on_save(bufnr)
    local view = vim.fn.winsaveview()
    local changed = expand_buffer(bufnr)
    if changed > 0 then
        vim.fn.winrestview(view)
    end
end

--- Flip the global auto-expand flag and report its new state.
local function toggle_auto()
    if vim.g.table_toggle_auto_expand == false then
        vim.g.table_toggle_auto_expand = true
        vim.notify('table toggle: auto-expand on', vim.log.levels.INFO)
    else
        vim.g.table_toggle_auto_expand = false
        vim.notify('table toggle: auto-expand off', vim.log.levels.INFO)
    end
end

--- Toggle and report: rewrites on success (naming the line when the
--- fallback picked the target), notifies the reason on refusal.
local function toggle()
    local ok, detail = toggle_at_cursor()
    if not ok then
        vim.notify('table toggle: ' .. (detail or 'no change'), vim.log.levels.WARN)
    elseif detail then
        vim.notify('table toggle: ' .. detail, vim.log.levels.INFO)
    end
end

---@class TableToggleOpts
---@field auto_expand_on_save? boolean expand eligible tables on BufWritePre
---@field keymap? string optional normal-mode mapping for the toggle

--- Create the :TableToggle command (and the mapping, when asked).
--- With auto_expand_on_save, also wire the BufWritePre pass and the
--- :TableToggleAuto kill-switch command.
---@param opts? TableToggleOpts
local function setup(opts)
    opts = opts or {}
    api.nvim_create_user_command('TableToggle', toggle, {
        desc = 'Expand or collapse the table constructor at the cursor',
    })
    if opts.keymap then
        vim.keymap.set('n', opts.keymap, toggle, { desc = 'Toggle table shape' })
    end
    if opts.auto_expand_on_save and not stage_registered then
        -- Save-time work in this config belongs to the formatters
        -- pipeline: a direct BufWritePre trips its ownership guard.
        -- Priority 100 runs ahead of the format stages (900/1000),
        -- so they normalize the expanded shape in the same save.
        require('formatters').register_stage({
            desc = 'Expand eligible single-line tables before formatting',
            filetypes = { 'lua' },
            name = 'table_toggle_expand',
            priority = 100,
            run = function(bufnr)
                on_save(bufnr)
                return true
            end,
        })
        stage_registered = true
        api.nvim_create_user_command('TableToggleAuto', toggle_auto, {
            desc = 'Flip table auto-expand on save for this session',
        })
    end
end

M.expand_buffer = expand_buffer
M.setup = setup
M.toggle = toggle
-- Pure core, exposed for the busted specs.
M._plan = plan
M._split_fields = split_fields

return M
