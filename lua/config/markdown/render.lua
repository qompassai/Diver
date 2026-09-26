-- /qompassai/Diver/lua/config/markdown/render.lua
-- Qompass AI Diver Native Markdown Renderer
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- ELI5: Neovim can hide text (conceal) and draw little pictures over it
-- (extmarks). This module uses only those built-in tricks to make Markdown
-- files pretty -- bullets become ● ○ ◆ ◇, checkboxes become icons,
-- fenced code blocks get dimmed backgrounds with borders and language
-- labels, tables get box-drawing borders, and so on. No plugin needed.
--
-- This replaces render-markdown.nvim. Only the old config's `enabled = true`
-- features are replicated (headings stay plain, exactly like before):
--   * fenced code blocks: full-row background, sign column marker,
--     top/bottom borders, language icon + name + info on the top line,
--     inline `code` highlighting
--   * thematic breaks, bullets (nested icons, ordered renumbering),
--     checkboxes (including the custom [-] todo), blockquotes (nested ▋
--     with per-level colors), pipe tables (box borders, ━ delimiter row),
--     callouts ([!NOTE]/[!TIP]/[!WARNING]... github + obsidian sets),
--     links (per-domain icons), footnotes, wiki links, ==highlights==,
--     indent guides (▎), HTML comments
--   * conceallevel 3, anti-conceal (the line under the cursor always shows
--     raw Markdown so editing never fights the icons), 100 ms debounce,
--     100 MB file guard, render on TextChanged / InsertLeave / BufWinEnter
--
-- Deliberately line-based: it never depends on the markdown treesitter
-- parser being installed, which keeps rendering deterministic and the
-- headless tests honest. Not replicated: LaTeX rendering (needs an
-- external lualatex -> image converter) and the old plugin's completion
-- filters (those belonged to blink.cmp/coq, not rendering).

local api = vim.api

local M = {}

-- Named bounds: every loop, table and width below is capped by one of these.
local DEBOUNCE_MS = 100
local MAX_FILE_SIZE_MB = 100
local MAX_LINE_COUNT_FALLBACK = 200000
local MAX_TABLE_ROWS = 2000
local MAX_TABLE_COLS = 16
local MAX_TABLE_COL_WIDTH = 48
local INDENT_PER_LEVEL = 2
local INDENT_SKIP_LEVEL = 1
local BORDER_WIDTH_FALLBACK = 80
local BORDER_WIDTH_MAX = 200

local NAMESPACE = 'diver_markdown_render'
local AUGROUP = 'DiverMarkdownRender'

-- Plain-ASCII icons; nerd-font glyphs arrive via @@PLACEHOLDERS@@ replaced
-- from the old config so the exact codepoints survive transcription.
local BULLET_ICONS = { '●', '○', '◆', '◇' }
local QUOTE_ICON = '▋'
local INDENT_ICON = '▎'
local DASH_ICON = '─'
local TABLE_V = '│'
local TABLE_H = '─'
local TABLE_ALIGN = '━'
local CODE_BORDER_TOP = '▄'
local CODE_BORDER_BOTTOM = '▀'

---@class DiverMarkdownOptions
---@field enabled? boolean
---@field debounce_ms? integer
---@field max_file_size_mb? number
---@field filetypes? string[]

local defaults = {
    enabled = true,
    debounce_ms = DEBOUNCE_MS,
    max_file_size_mb = MAX_FILE_SIZE_MB,
    filetypes = { 'markdown', 'mdx', 'markdown.mdx' },
}

---@type DiverMarkdownOptions
local config = vim.deepcopy(defaults)

local state = {
    setup_done = false,
    timer = nil,
    pending = {},
    win_defaults = {},
}

local ns = api.nvim_create_namespace(NAMESPACE)

-- Highlight groups this module owns. `default = true` so a colorscheme (or
-- the user) can override any of them without a fight.
local HL_DEFS = {
    { 'DiverMarkdownCode', 'CursorLine' },
    { 'DiverMarkdownCodeBorder', 'FloatBorder' },
    { 'DiverMarkdownCodeInfo', 'Title' },
    { 'DiverMarkdownCodeInline', 'String' },
    { 'DiverMarkdownDash', 'Comment' },
    { 'DiverMarkdownBullet', 'Delimiter' },
    { 'DiverMarkdownUnchecked', 'Comment' },
    { 'DiverMarkdownChecked', 'DiagnosticOk' },
    { 'DiverMarkdownTodo', 'DiagnosticWarn' },
    { 'DiverMarkdownQuote1', 'Comment' },
    { 'DiverMarkdownQuote2', 'String' },
    { 'DiverMarkdownQuote3', 'Function' },
    { 'DiverMarkdownQuote4', 'Keyword' },
    { 'DiverMarkdownQuote5', 'Type' },
    { 'DiverMarkdownQuote6', 'Number' },
    { 'DiverMarkdownTableHead', 'Title' },
    { 'DiverMarkdownTableRow', 'Normal' },
    { 'DiverMarkdownTableBorder', 'FloatBorder' },
    { 'DiverMarkdownInfo', 'DiagnosticInfo' },
    { 'DiverMarkdownSuccess', 'DiagnosticOk' },
    { 'DiverMarkdownHint', 'DiagnosticHint' },
    { 'DiverMarkdownWarn', 'DiagnosticWarn' },
    { 'DiverMarkdownError', 'DiagnosticError' },
    { 'DiverMarkdownQuoteCallout', 'Comment' },
    { 'DiverMarkdownLink', 'Underlined' },
    { 'DiverMarkdownWikiLink', 'Underlined' },
    { 'DiverMarkdownInlineHighlight', 'Search' },
    { 'DiverMarkdownIndent', 'Whitespace' },
    { 'DiverMarkdownHtmlComment', 'Comment' },
    { 'DiverMarkdownSign', 'SignColumn' },
}

-- Callouts replicate the old config's github + obsidian sets verbatim
-- (raw marker -> rendered text + highlight). Glyphs are @@PLACEHOLDERS@@.
---@type table<string, { rendered: string, hl: string }>
local CALLOUTS = {
    NOTE = { rendered = '󰋽 Note', hl = 'DiverMarkdownInfo' },
    TIP = { rendered = '󰌶 Tip', hl = 'DiverMarkdownSuccess' },
    IMPORTANT = { rendered = '󰅾 Important', hl = 'DiverMarkdownHint' },
    WARNING = { rendered = '󰀪 Warning', hl = 'DiverMarkdownWarn' },
    CAUTION = { rendered = '󰳦 Caution', hl = 'DiverMarkdownError' },
    ABSTRACT = { rendered = '󰨸 Abstract', hl = 'DiverMarkdownInfo' },
    SUMMARY = { rendered = '󰨸 Summary', hl = 'DiverMarkdownInfo' },
    TLDR = { rendered = '󰨸 Tldr', hl = 'DiverMarkdownInfo' },
    INFO = { rendered = '󰋽 Info', hl = 'DiverMarkdownInfo' },
    TODO = { rendered = '󰗡 Todo', hl = 'DiverMarkdownInfo' },
    HINT = { rendered = '󰌶 Hint', hl = 'DiverMarkdownSuccess' },
    SUCCESS = { rendered = '󰄬 Success', hl = 'DiverMarkdownSuccess' },
    CHECK = { rendered = '󰄬 Check', hl = 'DiverMarkdownSuccess' },
    DONE = { rendered = '󰄬 Done', hl = 'DiverMarkdownSuccess' },
    QUESTION = { rendered = '󰘥 Question', hl = 'DiverMarkdownWarn' },
    HELP = { rendered = '󰘥 Help', hl = 'DiverMarkdownWarn' },
    FAQ = { rendered = '󰘥 Faq', hl = 'DiverMarkdownWarn' },
    ATTENTION = { rendered = '󰀪 Attention', hl = 'DiverMarkdownWarn' },
    FAILURE = { rendered = '󰅖 Failure', hl = 'DiverMarkdownError' },
    FAIL = { rendered = '󰅖 Fail', hl = 'DiverMarkdownError' },
    MISSING = { rendered = '󰅖 Missing', hl = 'DiverMarkdownError' },
    DANGER = { rendered = '󱐌 Danger', hl = 'DiverMarkdownError' },
    ERROR = { rendered = '󱐌 Error', hl = 'DiverMarkdownError' },
    BUG = { rendered = '󰨰 Bug', hl = 'DiverMarkdownError' },
    EXAMPLE = { rendered = '󰉹 Example', hl = 'DiverMarkdownHint' },
    QUOTE = { rendered = '󱆨 Quote', hl = 'DiverMarkdownQuoteCallout' },
    CITE = { rendered = '󱆨 Cite', hl = 'DiverMarkdownQuoteCallout' },
}

-- Per-domain link icons, first match wins (mirrors the old `custom` table
-- order, with the `^http` web fallback last).
---@type { pattern: string, icon: string }[]
local LINK_DOMAINS = {
    { pattern = 'discord%.com', icon = '󰙯 ' },
    { pattern = 'github%.com', icon = '󰊤 ' },
    { pattern = 'gitlab%.com', icon = '󰮠 ' },
    { pattern = 'google%.com', icon = '󰊭 ' },
    { pattern = 'neovim%.io', icon = ' ' },
    { pattern = 'reddit%.com', icon = '󰑍 ' },
    { pattern = 'stackoverflow%.com', icon = '󰓌 ' },
    { pattern = 'wikipedia%.org', icon = '󰖬 ' },
    { pattern = 'youtube%.com', icon = '󰗃 ' },
    { pattern = '^http', icon = '󰖟 ' },
}

local ICON_IMAGE = '󰥶 '
local ICON_EMAIL = '󰀓 '
local ICON_HYPERLINK = '󰌹 '
local ICON_WIKI = '󱗖 '
local ICON_UNCHECKED = '󰄱 '
local ICON_CHECKED = '󰄱 '
local ICON_TODO = '󰥔 '

local SUPERSCRIPT = {
    ['0'] = '⁰',
    ['1'] = '¹',
    ['2'] = '²',
    ['3'] = '³',
    ['4'] = '⁴',
    ['5'] = '⁵',
    ['6'] = '⁶',
    ['7'] = '⁷',
    ['8'] = '⁸',
    ['9'] = '⁹',
}

local function define_highlights()
    for _, def in ipairs(HL_DEFS) do
        api.nvim_set_hl(0, def[1], { link = def[2], default = true })
    end
end

---@param value any
---@return boolean
local function positive_integer(value)
    return type(value) == 'number' and value == math.floor(value) and value > 0
end

---@param options table?
---@return DiverMarkdownOptions
local function validate_options(options)
    if options == nil then
        return vim.deepcopy(defaults)
    end
    assert(type(options) == 'table', 'markdown render options must be a table')

    if options.enabled ~= nil then
        assert(type(options.enabled) == 'boolean', 'markdown render enabled must be a boolean')
    end
    if options.debounce_ms ~= nil then
        assert(positive_integer(options.debounce_ms), 'markdown render debounce_ms must be a positive integer')
    end
    if options.max_file_size_mb ~= nil then
        assert(
            type(options.max_file_size_mb) == 'number' and options.max_file_size_mb > 0,
            'markdown render max_file_size_mb must be a positive number'
        )
    end
    if options.filetypes ~= nil then
        assert(type(options.filetypes) == 'table', 'markdown render filetypes must be a list')
        for _, ft in ipairs(options.filetypes) do
            assert(type(ft) == 'string' and ft ~= '', 'markdown render filetypes must be non-empty strings')
        end
    end

    return vim.tbl_deep_extend('force', vim.deepcopy(defaults), options)
end

---@param bufnr integer
---@param row integer 0-based
---@param col integer 0-based
---@param opts table extmark options
---@return integer extmark id
local function mark(bufnr, row, col, opts)
    assert(api.nvim_buf_is_valid(bufnr), 'mark requires a valid buffer')
    return api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
end

-- Hide [col_s, col_e) on the line.
---@param bufnr integer
---@param row integer 0-based
---@param col_s integer 0-based inclusive
---@param col_e integer 0-based exclusive
local function conceal_span(bufnr, row, col_s, col_e)
    if col_e > col_s then
        mark(bufnr, row, col_s, { end_col = col_e, conceal = '' })
    end
end

-- Hide [col_s, col_e) and draw `text` over it.
---@param bufnr integer
---@param row integer 0-based
---@param col_s integer 0-based inclusive
---@param col_e integer 0-based exclusive
---@param text string
---@param hl string
local function overlay(bufnr, row, col_s, col_e, text, hl)
    mark(bufnr, row, col_s, {
        end_col = col_e,
        conceal = '',
        virt_text = { { text, hl } },
        virt_text_pos = 'overlay',
    })
end

-- Draw `text` inline at (row, col) without hiding anything.
---@param bufnr integer
---@param row integer 0-based
---@param col integer 0-based
---@param text string
---@param hl string
local function inline_icon(bufnr, row, col, text, hl)
    mark(bufnr, row, col, {
        virt_text = { { text, hl } },
        virt_text_pos = 'inline',
    })
end

---@param bufnr integer
---@param row integer 0-based
---@param hl string
local function place_sign(bufnr, row, hl)
    mark(bufnr, row, 0, { sign_text = ' ', sign_hl_group = hl })
end

-- Window options: conceallevel 3 everywhere, anti-conceal on the cursor
-- line via concealcursor (the old plugin's anti_conceal equivalent).
local function set_window_options()
    local win = api.nvim_get_current_win()
    if not api.nvim_win_is_valid(win) then
        return
    end
    if state.win_defaults[win] == nil then
        state.win_defaults[win] = {
            conceallevel = vim.wo[win].conceallevel,
            concealcursor = vim.wo[win].concealcursor,
        }
    end
    vim.wo[win].conceallevel = 3
    vim.wo[win].concealcursor = 'nvic'
end

local function restore_window_options()
    local win = api.nvim_get_current_win()
    local saved = state.win_defaults[win]
    if saved == nil or not api.nvim_win_is_valid(win) then
        return
    end
    vim.wo[win].conceallevel = saved.conceallevel
    vim.wo[win].concealcursor = saved.concealcursor
    state.win_defaults[win] = nil
end

-- Language icon + display name from the repo's own devicons table
-- (config.ui.icons); no plugin dependency, plain table lookup.
---@type table<string, { icon: string, name: string }>?
local devicons_override = nil

---@param lang string
---@return string icon, string name
local function language_icon(lang)
    if devicons_override == nil then
        devicons_override = {}
        local ok, icons = pcall(require, 'config.ui.icons')
        if ok and type(icons) == 'table' and type(icons.devicons) == 'table' then
            local override = icons.devicons.override
            if type(override) == 'table' then
                devicons_override = override
            end
        end
    end
    assert(devicons_override ~= nil, 'devicons table must be initialized')
    local entry = devicons_override[lang:lower()]
    if type(entry) == 'table' and type(entry.icon) == 'string' then
        local name = type(entry.name) == 'string' and entry.name or lang
        return vim.trim(entry.icon), name
    end
    return '', lang
end

-- Find `code` spans: { s, e } 1-based inclusive bounds of the whole span
-- (backticks included), plus inner bounds without the backticks.
---@param seg string
---@return { s: integer, e: integer, inner_s: integer, inner_e: integer }[]
local function code_spans(seg)
    local spans = {}
    local i, n = 1, #seg
    while i <= n do
        local s, e = seg:find('`+', i)
        if s == nil or e == nil then
            break
        end
        local run = (e - s) + 1
        local found = false
        local j = e + 1
        while j <= n do
            local s2, e2 = seg:find('`+', j)
            if s2 == nil or e2 == nil then
                break
            end
            if ((e2 - s2) + 1) == run then
                spans[#spans + 1] = { s = s, e = e2, inner_s = e + 1, inner_e = s2 - 1 }
                i = e2 + 1
                found = true
                break
            end
            j = e2 + 1
        end
        if not found then
            i = e + 1
        end
    end
    return spans
end

---@param spans { s: integer, e: integer }[]
---@param s integer 1-based inclusive
---@param e integer 1-based inclusive
---@return boolean
local function overlaps(spans, s, e)
    for _, span in ipairs(spans) do
        if s <= span.e and e >= span.s then
            return true
        end
    end
    return false
end

---@param text string
---@return string
local function superscript(text)
    return (text:gsub('.', function(char)
        return SUPERSCRIPT[char] or char
    end))
end

---@param url string
---@return string icon
local function domain_icon(url)
    for _, entry in ipairs(LINK_DOMAINS) do
        if url:find(entry.pattern) ~= nil then
            return entry.icon
        end
    end
    return ICON_HYPERLINK
end

-- Width for full-width borders: the first window showing the buffer wins,
-- clamped; headless or hidden buffers fall back to 80.
---@param bufnr integer
---@return integer
local function border_width(bufnr)
    for _, win in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == bufnr then
            return math.min(BORDER_WIDTH_MAX, math.max(1, api.nvim_win_get_width(win)))
        end
    end
    return BORDER_WIDTH_FALLBACK
end

---@param bufnr integer
---@return boolean too_big
local function file_too_big(bufnr)
    local name = api.nvim_buf_get_name(bufnr)
    if name ~= '' then
        local stat = vim.uv.fs_stat(name)
        if stat ~= nil and stat.size ~= nil then
            return stat.size > config.max_file_size_mb * 1024 * 1024
        end
    end
    return api.nvim_buf_line_count(bufnr) > MAX_LINE_COUNT_FALLBACK
end

-- Fenced code blocks: conceal the ``` line, draw the language label over
-- it, add a top border above; the closing fence gets a bottom border.
---@param bufnr integer
---@param row integer 0-based
---@param line string
---@param width integer
local function render_fence_open(bufnr, row, line, width)
    local info = line:match('^%s*```%s*(.-)%s*$') or ''
    local lang, rest = info:match('^(%S+)%s*(.-)%s*$')
    lang = lang or ''
    rest = rest or ''

    local parts = {}
    if lang ~= '' then
        local icon, name = language_icon(lang)
        if icon ~= '' then
            parts[#parts + 1] = icon
        end
        parts[#parts + 1] = name
    end
    if rest ~= '' then
        parts[#parts + 1] = rest
    end
    local label = table.concat(parts, ' ')

    overlay(bufnr, row, 0, #line, label, 'DiverMarkdownCodeInfo')
    mark(bufnr, row, 0, {
        virt_lines = { { { string.rep(CODE_BORDER_TOP, width), 'DiverMarkdownCodeBorder' } } },
        virt_lines_above = true,
    })
    place_sign(bufnr, row, 'DiverMarkdownSign')
end

---@param bufnr integer
---@param row integer 0-based
---@param line string
---@param width integer
local function render_fence_close(bufnr, row, line, width)
    conceal_span(bufnr, row, 0, #line)
    mark(bufnr, row, 0, {
        virt_lines = { { { string.rep(CODE_BORDER_BOTTOM, width), 'DiverMarkdownCodeBorder' } } },
    })
    place_sign(bufnr, row, 'DiverMarkdownSign')
end

---@param bufnr integer
---@param row integer 0-based
local function render_code_line(bufnr, row)
    mark(bufnr, row, 0, {
        line_hl_group = 'DiverMarkdownCode',
        sign_text = ' ',
        sign_hl_group = 'DiverMarkdownSign',
    })
end

---@param bufnr integer
---@param row integer 0-based
---@param line string
---@param width integer
local function render_dash(bufnr, row, line, width)
    overlay(bufnr, row, 0, #line, string.rep(DASH_ICON, width), 'DiverMarkdownDash')
    place_sign(bufnr, row, 'DiverMarkdownSign')
end

---@param bufnr integer
---@param row integer 0-based
---@param indent string
---@param markers string
---@param rest string
local function render_callout(bufnr, row, indent, markers, rest)
    local word = rest:match('^%[!([%w]+)%]')
    if word == nil then
        return nil
    end
    local callout = CALLOUTS[word:upper()]
    if callout == nil then
        return nil
    end
    local raw = '[!' .. word .. ']'
    local col_s = #indent + #markers
    conceal_span(bufnr, row, col_s, col_s + #raw)
    mark(bufnr, row, col_s, {
        virt_text = { { callout.rendered, callout.hl } },
        virt_text_pos = 'overlay',
    })
    return col_s + #raw
end

-- Split a quote line into leading indent, the `>` marker run (with its
-- trailing spaces), the nesting level and the remaining text. Parsed by
-- hand because Lua patterns cannot quantify a capture group.
---@param line string
---@return string? indent, string? markers, integer? level, string? rest
local function parse_quote(line)
    local indent = line:match('^%s*') or ''
    local pos = #indent + 1
    local level = 0
    while line:sub(pos, pos) == '>' do
        level = level + 1
        pos = pos + 1
        local spaces = line:match('^%s*', pos) or ''
        pos = pos + #spaces
    end
    if level == 0 then
        return nil, nil, nil, nil
    end
    local markers = line:sub(#indent + 1, pos - 1)
    return indent, markers, level, line:sub(pos)
end

-- Blockquotes: conceal the `>` run, overlay one ▋ per nesting level with
-- cycling per-level colors; a leading [!CALLOUT] gets its icon + label.
---@param bufnr integer
---@param row integer 0-based
---@param line string
---@return integer content_col 0-based column where inline content starts
local function render_quote(bufnr, row, line)
    local indent, markers, level, rest = parse_quote(line)
    assert(indent ~= nil and markers ~= nil and level ~= nil and rest ~= nil, 'quote must parse its own markers')
    assert(level >= 1, 'quote needs at least one > marker')

    local chunks = {}
    for depth = 1, level do
        chunks[#chunks + 1] = { QUOTE_ICON, 'DiverMarkdownQuote' .. ((depth - 1) % 6 + 1) }
    end
    local col_s = #indent
    local col_e = col_s + #markers
    mark(bufnr, row, col_s, {
        end_col = col_e,
        conceal = '',
        virt_text = chunks,
        virt_text_pos = 'overlay',
    })

    local after = render_callout(bufnr, row, indent, markers, rest)
    if after ~= nil then
        return after
    end
    return col_e
end

-- Indent guides (▎) in the leading whitespace, skipping the first level.
---@param bufnr integer
---@param row integer 0-based
---@param indent_width integer
local function render_indent_guides(bufnr, row, indent_width)
    local level = INDENT_SKIP_LEVEL
    while level * INDENT_PER_LEVEL < indent_width do
        local col = level * INDENT_PER_LEVEL
        mark(bufnr, row, col, {
            virt_text = { { INDENT_ICON, 'DiverMarkdownIndent' } },
            virt_text_pos = 'overlay',
        })
        level = level + 1
    end
end

---@param bufnr integer
---@param row integer 0-based
---@param col_s integer 0-based
---@param marker string ' ', 'x', 'X' or '-'
local function render_checkbox(bufnr, row, col_s, marker)
    local icon, hl = ICON_UNCHECKED, 'DiverMarkdownUnchecked'
    if marker == 'x' or marker == 'X' then
        icon, hl = ICON_CHECKED, 'DiverMarkdownChecked'
    elseif marker == '-' then
        icon, hl = ICON_TODO, 'DiverMarkdownTodo'
    end
    -- right_pad = 1 from the old config: trailing space after the icon.
    overlay(bufnr, row, col_s, col_s + 3, icon .. ' ', hl)
end

---@param bufnr integer
---@param row integer 0-based
---@param indent string
---@param marker string bullet or ordered marker text
---@param ws string whitespace after the marker
---@param content string
---@param st table scan state
---@return integer content_col 0-based column where inline content starts
local function render_list_item(bufnr, row, indent, marker, ws, content, st)
    local level = math.floor(#indent / INDENT_PER_LEVEL) + 1
    local icon = BULLET_ICONS[(level - 1) % #BULLET_ICONS + 1]

    local digits = marker:match('^(%d+)$')
    if digits ~= nil then
        if st.list_indent == indent then
            st.list_index = st.list_index + 1
        else
            st.list_indent = indent
            st.list_index = 1
        end
        local value = tonumber(digits) or 1
        -- Old ordered_icons: keep the written number when > 1, else the
        -- item's position in the list.
        icon = (value > 1 and digits or tostring(st.list_index)) .. '.'
    end

    local col_s = #indent
    local col_e = col_s + #marker + #ws
    overlay(bufnr, row, col_s, col_e, icon .. ' ', 'DiverMarkdownBullet')
    render_indent_guides(bufnr, row, #indent)

    local box = content:match('^%[([ xX%-])%]')
    if box ~= nil then
        render_checkbox(bufnr, row, col_e, box)
        return col_e + 3
    end
    return col_e
end

-- Pipe tables ----------------------------------------------------------

-- A delimiter row looks like `| --- | :---: | ---: |`. Returns the column
-- count, or nil when the line is not a delimiter row.
---@param line string
---@return integer? col_count
local function delimiter_col_count(line)
    local compact = line:gsub('%s', '')
    if compact:find('|', 1, true) == nil then
        return nil
    end
    local body = compact:gsub('^|', ''):gsub('|$', '')
    local count = 0
    for cell in (body .. '|'):gmatch('([^|]*)|') do
        local inner = cell:gsub('^:', ''):gsub(':$', '')
        if inner:match('^%-+$') == nil then
            return nil
        end
        count = count + 1
        if count > MAX_TABLE_COLS then
            return nil
        end
    end
    if count == 0 then
        return nil
    end
    return count
end

-- Split a table row into trimmed cells; `\|` stays inside a cell.
---@param line string
---@return string[]
local function split_cells(line)
    local stripped = line:gsub('^%s*|', ''):gsub('|%s*$', '')
    local cells = {}
    local cur = {}
    local i, n = 1, #stripped
    while i <= n do
        local char = stripped:sub(i, i)
        if char == '\\' and i < n then
            cur[#cur + 1] = stripped:sub(i, i + 1)
            i = i + 2
        elseif char == '|' then
            cells[#cells + 1] = vim.trim(table.concat(cur))
            cur = {}
            i = i + 1
        else
            cur[#cur + 1] = char
            i = i + 1
        end
    end
    cells[#cells + 1] = vim.trim(table.concat(cur))
    return cells
end

-- Overlay │ on every unescaped `|` in the line.
---@param bufnr integer
---@param row integer 0-based
---@param line string
local function render_pipes(bufnr, row, line)
    local i, n = 1, #line
    while i <= n do
        local char = line:sub(i, i)
        if char == '\\' then
            i = i + 2
        elseif char == '|' then
            overlay(bufnr, row, i - 1, i, TABLE_V, 'DiverMarkdownTableBorder')
            i = i + 1
        else
            i = i + 1
        end
    end
end

---@param bufnr integer
---@param start_row integer 0-based row of the header line
---@param rows string[] header, delimiter, then body rows
local function render_table_block(bufnr, start_row, rows)
    local col_count = 0
    local parsed = {}
    for _, line in ipairs(rows) do
        local cells = split_cells(line)
        parsed[#parsed + 1] = cells
        col_count = math.min(MAX_TABLE_COLS, math.max(col_count, #cells))
    end

    local widths = {}
    for col = 1, col_count do
        local width = 0
        for _, cells in ipairs(parsed) do
            local cell = cells[col] or ''
            width = math.max(width, vim.fn.strdisplaywidth(cell))
        end
        widths[col] = math.min(MAX_TABLE_COL_WIDTH, width)
    end

    local function border(left, mid, right)
        local cells = {}
        for col = 1, col_count do
            cells[#cells + 1] = string.rep(TABLE_H, widths[col] + 2)
        end
        return left .. table.concat(cells, mid) .. right
    end

    for index, line in ipairs(rows) do
        local row = start_row + index - 1
        if index == 1 then
            render_pipes(bufnr, row, line)
            mark(bufnr, row, 0, { line_hl_group = 'DiverMarkdownTableHead' })
            mark(bufnr, row, 0, {
                virt_lines = { { { border('┌', '┬', '┐'), 'DiverMarkdownTableBorder' } } },
                virt_lines_above = true,
            })
        elseif index == 2 then
            -- Delimiter row: hide the dashes, show the ━ alignment row.
            local cells = {}
            for col = 1, col_count do
                cells[#cells + 1] = string.rep(TABLE_ALIGN, widths[col])
            end
            local rebuilt = TABLE_V .. ' ' .. table.concat(cells, ' ' .. TABLE_V .. ' ') .. ' ' .. TABLE_V
            overlay(bufnr, row, 0, #line, rebuilt, 'DiverMarkdownTableBorder')
        else
            render_pipes(bufnr, row, line)
            mark(bufnr, row, 0, { line_hl_group = 'DiverMarkdownTableRow' })
        end
    end

    local last_row = start_row + #rows - 1
    mark(bufnr, last_row, 0, {
        virt_lines = { { { border('└', '┴', '┘'), 'DiverMarkdownTableBorder' } } },
    })
end

-- Inline elements ------------------------------------------------------

---@param bufnr integer
---@param row integer 0-based
---@param seg string the text segment to decorate
---@param base_col integer 0-based column of seg start in the line
local function render_inline(bufnr, row, seg, base_col)
    if seg == '' then
        return
    end
    local spans = code_spans(seg)
    for _, span in ipairs(spans) do
        conceal_span(bufnr, row, base_col + span.s - 1, base_col + span.inner_s - 1)
        conceal_span(bufnr, row, base_col + span.inner_e, base_col + span.e)
        mark(bufnr, row, base_col + span.inner_s - 1, {
            end_col = base_col + span.inner_e,
            hl_group = 'DiverMarkdownCodeInline',
        })
    end
    local used = {}
    for _, span in ipairs(spans) do
        used[#used + 1] = span
    end

    -- ==highlighted== (conceal the ==, highlight the middle).
    local init = 1
    while init <= #seg do
        local s, e = seg:find('==([^=]-)==', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            conceal_span(bufnr, row, base_col + s - 1, base_col + s + 1)
            conceal_span(bufnr, row, base_col + e - 2, base_col + e - 1)
            mark(bufnr, row, base_col + s + 1, {
                end_col = base_col + e - 2,
                hl_group = 'DiverMarkdownInlineHighlight',
            })
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- Images: ![alt](src) -> icon + alt text.
    init = 1
    while init <= #seg do
        local s, e, alt = seg:find('!%[([^%]]*)%]%([^)]*%)', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            conceal_span(bufnr, row, base_col + s - 1, base_col + s + 1)
            inline_icon(bufnr, row, base_col + s + 1, ICON_IMAGE, 'DiverMarkdownLink')
            local url_start = seg:find('%](', s, true)
            if url_start ~= nil then
                conceal_span(bufnr, row, base_col + url_start - 1, base_col + e)
            end
            mark(bufnr, row, base_col + s + 1, {
                end_col = base_col + s + 1 + #alt,
                hl_group = 'DiverMarkdownLink',
            })
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- Links: [text](url) -> text + per-domain icon.
    init = 1
    while init <= #seg do
        local s, e, text, url = seg:find('%[([^%]]+)%]%(([^)]+)%)', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            local icon = url:match('^mailto:') ~= nil and ICON_EMAIL or domain_icon(url)
            conceal_span(bufnr, row, base_col + s - 1, base_col + s)
            mark(bufnr, row, base_col + s, {
                end_col = base_col + s + #text,
                hl_group = 'DiverMarkdownLink',
            })
            local url_start = seg:find('%](', s, true)
            if url_start ~= nil then
                conceal_span(bufnr, row, base_col + url_start - 1, base_col + e)
            end
            inline_icon(bufnr, row, base_col + s + #text, icon, 'DiverMarkdownLink')
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- Footnotes: [^id] -> superscript id.
    init = 1
    while init <= #seg do
        local s, e, id = seg:find('%[%^([%w_%-]+)%]', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            overlay(bufnr, row, base_col + s - 1, base_col + e, superscript(id), 'DiverMarkdownLink')
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- Wiki links: [[page]] -> icon + page.
    init = 1
    while init <= #seg do
        local s, e, page = seg:find('%[%[([^%]]+)%]%]', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            conceal_span(bufnr, row, base_col + s - 1, base_col + s + 1)
            conceal_span(bufnr, row, base_col + e - 2, base_col + e - 1)
            inline_icon(bufnr, row, base_col + s + 1, ICON_WIKI, 'DiverMarkdownWikiLink')
            mark(bufnr, row, base_col + s + 1, {
                end_col = base_col + s + 1 + #page,
                hl_group = 'DiverMarkdownWikiLink',
            })
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- Email autolinks: <name@example.com>.
    init = 1
    while init <= #seg do
        local s, e, addr = seg:find('<([%w._%%+-]+@[%w%.%-]+)>', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            conceal_span(bufnr, row, base_col + s - 1, base_col + s)
            conceal_span(bufnr, row, base_col + e - 1, base_col + e)
            inline_icon(bufnr, row, base_col + s, ICON_EMAIL, 'DiverMarkdownLink')
            mark(bufnr, row, base_col + s, {
                end_col = base_col + s + #addr,
                hl_group = 'DiverMarkdownLink',
            })
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end

    -- HTML comments: highlight only (old config: conceal = false).
    init = 1
    while init <= #seg do
        local s, e = seg:find('<!%-%-.-%-%->', init)
        if s == nil or e == nil then
            break
        end
        if not overlaps(used, s, e) then
            mark(bufnr, row, base_col + s - 1, {
                end_col = base_col + e - 1,
                hl_group = 'DiverMarkdownHtmlComment',
            })
            used[#used + 1] = { s = s, e = e }
        end
        init = e + 1
    end
end

-- Line dispatcher ------------------------------------------------------

-- Headings are intentionally untouched: the old config had
-- `heading.enabled = false`, and this module keeps that behavior.

---@param str string
---@return boolean
local function is_thematic_break(str)
    local compact = str:gsub('%s', '')
    if #compact < 3 then
        return false
    end
    return compact:match('^%*+$') ~= nil or compact:match('^%-+$') ~= nil or compact:match('^_+$') ~= nil
end

---@param bufnr integer
---@param lines string[]
---@param row integer 0-based
---@param width integer
---@param st table scan state
---@return integer next_row 0-based row to continue from
local function render_line(bufnr, lines, row, width, st)
    local line = lines[row + 1]
    assert(line ~= nil, 'render_line needs a line for every row')

    -- Inside a fenced block: only the closing fence matters.
    if st.fence ~= nil then
        if line:match('^%s*```%s*$') ~= nil then
            render_fence_close(bufnr, row, line, width)
            st.fence = nil
        else
            render_code_line(bufnr, row)
        end
        st.list_indent = nil
        return row + 1
    end

    -- Fence opens before anything else on the line.
    if line:match('^%s*```') ~= nil then
        render_fence_open(bufnr, row, line, width)
        st.fence = true
        st.list_indent = nil
        return row + 1
    end

    -- Blockquote (callouts fold into this branch).
    if line:match('^%s*>') ~= nil then
        local content_col = render_quote(bufnr, row, line)
        render_indent_guides(bufnr, row, #(line:match('^(%s*)') or ''))
        render_inline(bufnr, row, line:sub(content_col + 1), content_col)
        st.list_indent = nil
        return row + 1
    end

    -- Pipe table: header line followed by a delimiter row.
    if line:find('|', 1, true) ~= nil and row + 1 < #lines then
        local delimiter = lines[row + 2]
        if delimiter ~= nil and delimiter_col_count(delimiter) ~= nil then
            local rows = { line, delimiter }
            local last = row + 1
            while last + 1 < #lines and #rows < MAX_TABLE_ROWS do
                local next_line = lines[last + 2]
                if next_line == nil or next_line:find('|', 1, true) == nil then
                    break
                end
                rows[#rows + 1] = next_line
                last = last + 1
            end
            render_table_block(bufnr, row, rows)
            st.list_indent = nil
            return last + 1
        end
    end

    -- Thematic break.
    if is_thematic_break(line) then
        render_dash(bufnr, row, line, width)
        st.list_indent = nil
        return row + 1
    end

    -- List items: unordered (-, *, +) or ordered (1., 1)).
    local indent, marker, ws, content = line:match('^(%s*)([-+*])(%s+)(.*)$')
    if indent == nil then
        local ordered_digits
        indent, ordered_digits, ws, content = line:match('^(%s*)(%d+)[.)](%s+)(.*)$')
        if indent ~= nil then
            marker = ordered_digits
        end
    end
    if indent ~= nil then
        local content_col = render_list_item(bufnr, row, indent, marker, ws, content, st)
        render_inline(bufnr, row, line:sub(content_col + 1), content_col)
        return row + 1
    end
    st.list_indent = nil

    -- Plain paragraph line: inline decorations only.
    -- (paragraph.left_margin/indent were 0 in the old config: a no-op.)
    render_inline(bufnr, row, line, 0)
    return row + 1
end

---@param bufnr integer
local function render_buffer(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end
    if file_too_big(bufnr) then
        return
    end
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local width = border_width(bufnr)
    local st = { fence = nil, list_indent = nil, list_index = 0 }
    local row = 0
    while row < #lines do
        row = render_line(bufnr, lines, row, width, st)
    end
end

-- Debounce: TextChanged/InsertLeave/BufWinEnter only schedule; one uv timer
-- flushes every pending buffer. The timer has a single owner (this module).
local function flush()
    if state.timer ~= nil then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
    end
    local due = state.pending
    state.pending = {}
    for bufnr in pairs(due) do
        if api.nvim_buf_is_valid(bufnr) then
            render_buffer(bufnr)
        end
    end
end

---@param bufnr integer
local function schedule(bufnr)
    if not config.enabled then
        return
    end
    state.pending[bufnr] = true
    if state.timer ~= nil then
        return
    end
    local timer = vim.uv.new_timer()
    if timer == nil then
        flush()
        return
    end
    state.timer = timer
    timer:start(config.debounce_ms, 0, vim.schedule_wrap(flush))
end

---@param bufnr integer
---@return boolean attached
local function attach(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return false
    end
    if vim.b[bufnr].diver_markdown_render then
        return true
    end
    if not vim.tbl_contains(config.filetypes, vim.bo[bufnr].filetype) then
        return false
    end
    local group = api.nvim_create_augroup(AUGROUP, { clear = false })
    api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'BufWinEnter' }, {
        group = group,
        buffer = bufnr,
        callback = function(args)
            set_window_options()
            schedule(args.buf)
        end,
        desc = 'Schedule native Markdown render',
    })
    api.nvim_create_autocmd('BufLeave', {
        group = group,
        buffer = bufnr,
        callback = restore_window_options,
        desc = 'Restore window conceal options',
    })
    api.nvim_create_autocmd('BufWipeout', {
        group = group,
        buffer = bufnr,
        callback = function(args)
            api.nvim_buf_clear_namespace(args.buf, ns, 0, -1)
            vim.b[args.buf].diver_markdown_render = false
        end,
        desc = 'Clear native Markdown render state',
    })
    vim.b[bufnr].diver_markdown_render = true
    set_window_options()
    render_buffer(bufnr)
    return true
end

---@param bufnr integer
local function detach(bufnr)
    -- Drop any pending debounced render first: without this, a timer armed
    -- before disable() would fire afterwards and re-decorate the buffer.
    state.pending[bufnr] = nil
    if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        vim.b[bufnr].diver_markdown_render = false
    end
    pcall(api.nvim_clear_autocmds, { group = AUGROUP, buffer = bufnr })
    restore_window_options()
end

---Enable rendering for a buffer. Accepts nothing (current buffer), a
---buffer number, or the autocmd event table (FileType callbacks pass that).
---@param arg? integer|table
---@return boolean attached
function M.enable(arg)
    local bufnr
    if type(arg) == 'table' and type(arg.buf) == 'number' then
        bufnr = arg.buf
    elseif type(arg) == 'number' then
        bufnr = arg
    else
        bufnr = api.nvim_get_current_buf()
    end
    return attach(bufnr)
end

function M.disable()
    detach(api.nvim_get_current_buf())
end

function M.toggle()
    local bufnr = api.nvim_get_current_buf()
    if vim.b[bufnr].diver_markdown_render then
        M.disable()
    else
        M.enable(bufnr)
    end
end

---Render one buffer synchronously (debounce bypassed). Used by tests and
---by callers that just changed many lines at once.
---@param bufnr integer
function M.render(bufnr)
    render_buffer(bufnr)
end

---Schedule a debounced render (the TextChanged/InsertLeave/BufWinEnter path).
---@param bufnr integer
function M.schedule(bufnr)
    schedule(bufnr)
end

---@param options? DiverMarkdownOptions
function M.setup(options)
    config = validate_options(options)
    define_highlights()
    if state.setup_done then
        return
    end
    state.setup_done = true

    local group = api.nvim_create_augroup(AUGROUP, { clear = true })
    api.nvim_create_autocmd('FileType', {
        group = group,
        pattern = config.filetypes,
        callback = function(args)
            attach(args.buf)
        end,
        desc = 'Attach native Markdown renderer',
    })

    if config.enabled then
        attach(api.nvim_get_current_buf())
    end
end

return M
