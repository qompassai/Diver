-- Native Markdown renderer functional test.
-- Run from the repo root: ~/.local/bin/nvim --headless -u NONE -l tests/lua/markdown_render.lua
-- Exercises config.markdown.render end to end: extmarks, conceals,
-- highlights, window options, debounce, the file-size guard and idempotent
-- setup. No plugins, no network.
local api = vim.api
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local passed = 0
local failures = {}
local function check(value, message)
    if value then
        passed = passed + 1
    else
        failures[#failures + 1] = message
    end
end

local render = require('config.markdown.render')
check(type(render.setup) == 'function', 'render exposes setup()')
check(type(render.enable) == 'function', 'render exposes enable()')
check(type(render.render) == 'function', 'render exposes render()')

-- Idempotent setup: one augroup, no duplicate autocmds.
render.setup()
local function autocmd_count()
    return #api.nvim_get_autocmds({ group = 'DiverMarkdownRender' })
end
local owned = autocmd_count()
check(owned > 0, 'setup installs DiverMarkdownRender autocmds')
render.setup()
check(autocmd_count() == owned, 'second setup() does not duplicate autocmds')

-- Sample document covering every replicated feature.
local sample = {
    '# Title (headings stay plain)',
    '',
    '```lua',
    "print('hi')",
    '```',
    '',
    '---',
    '',
    '- item one',
    '  - nested item',
    '    - deep item',
    '1. first',
    '2. second',
    '- [ ] todo unchecked',
    '- [x] todo checked',
    '- [-] custom todo',
    '> a quote',
    '>> nested quote',
    '> [!NOTE] callout note',
    '> [!WARNING] callout warn',
    '',
    '| Name | Age |',
    '| ---- | ---:|',
    '| Ada  | 36  |',
    '',
    'A [link](https://github.com/qompassai/diver) and `code` and ==mark==.',
    'Footnote[^1] and [[WikiPage]] and <!-- a comment --> and <a@b.com>.',
    '',
    '[^1]: the footnote',
}
local path = vim.fn.tempname() .. '.md'
vim.fn.writefile(sample, path)
api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false } }, {})
local buf = api.nvim_get_current_buf()
vim.bo[buf].filetype = 'markdown'
api.nvim_exec_autocmds('FileType', { buffer = buf })

check(vim.b[buf].diver_markdown_render == true, 'FileType attaches the renderer')
check(vim.wo.conceallevel == 3, 'conceallevel is 3 in the markdown window')
check(vim.wo.concealcursor == 'nvic', 'anti-conceal lifts conceal on the cursor line')

local nsid = api.nvim_get_namespaces()['diver_markdown_render']
check(type(nsid) == 'number', 'namespace diver_markdown_render exists')

---@param row integer 0-based
local function marks_on(row)
    return api.nvim_buf_get_extmarks(buf, nsid, { row, 0 }, { row, -1 }, { details = true })
end

---@param row integer
---@param needle? string plain substring of a virt_text chunk
---@param hl? string expected highlight of that chunk
---@param pos? string 'overlay' or 'inline'
local function has_virt_text(row, needle, hl, pos)
    for _, m in ipairs(marks_on(row)) do
        local d = m[4]
        if d.virt_text ~= nil and (pos == nil or d.virt_text_pos == pos) then
            for _, chunk in ipairs(d.virt_text) do
                if (needle == nil or chunk[1]:find(needle, 1, true) ~= nil) and (hl == nil or chunk[2] == hl) then
                    return true
                end
            end
        end
    end
    return false
end

---@param row integer
---@param hl string
local function has_hl(row, hl)
    for _, m in ipairs(marks_on(row)) do
        local d = m[4]
        if d.hl_group == hl or d.line_hl_group == hl then
            return true
        end
    end
    return false
end

---@param row integer
local function has_conceal(row)
    for _, m in ipairs(marks_on(row)) do
        if m[4].conceal ~= nil then
            return true
        end
    end
    return false
end

---@param row integer
local function has_sign(row)
    for _, m in ipairs(marks_on(row)) do
        if m[4].sign_text ~= nil then
            return true
        end
    end
    return false
end

---@param row integer
---@param needle string plain substring of a virt_lines chunk
local function has_virt_lines(row, needle)
    for _, m in ipairs(marks_on(row)) do
        local d = m[4]
        if d.virt_lines ~= nil then
            for _, line in ipairs(d.virt_lines) do
                for _, chunk in ipairs(line) do
                    if chunk[1]:find(needle, 1, true) ~= nil then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Headings: disabled in the old config, untouched here.
check(#marks_on(0) == 0, 'heading line gets no decorations')

-- Fenced code block: label overlay, code background, borders, signs.
check(has_virt_text(2, 'Lua', 'DiverMarkdownCodeInfo', 'overlay'), 'fence open shows the language label')
check(has_hl(3, 'DiverMarkdownCode'), 'code line gets the full-row background')
check(has_conceal(2) and has_conceal(4), 'fence markers are concealed')
check(has_sign(2) and has_sign(3) and has_sign(4), 'code block lines get signs')
local top_border = false
for _, m in ipairs(marks_on(2)) do
    if m[4].virt_lines ~= nil then
        top_border = true
    end
end
check(top_border, 'fence open draws the top border')

-- Thematic break.
check(has_virt_text(6, '─', 'DiverMarkdownDash', 'overlay'), 'dash line renders the ─ icon')

-- Bullets: nesting cycle ● ○ ◆, indent guide ▎ on the deep item.
check(has_virt_text(8, '●', 'DiverMarkdownBullet', 'overlay'), 'level-1 bullet is ●')
check(has_virt_text(9, '○', 'DiverMarkdownBullet', 'overlay'), 'level-2 bullet is ○')
check(has_virt_text(10, '◆', 'DiverMarkdownBullet', 'overlay'), 'level-3 bullet is ◆')
check(has_virt_text(10, '▎', 'DiverMarkdownIndent', 'overlay'), 'deep indent shows the ▎ guide')

-- Ordered list numbering.
check(has_virt_text(11, '1.', 'DiverMarkdownBullet', 'overlay'), 'ordered item shows 1.')
check(has_virt_text(12, '2.', 'DiverMarkdownBullet', 'overlay'), 'ordered item shows 2.')

-- Checkboxes incl. the custom [-] todo.
check(has_virt_text(13, nil, 'DiverMarkdownUnchecked', 'overlay'), 'unchecked box icon')
check(has_virt_text(14, nil, 'DiverMarkdownChecked', 'overlay'), 'checked box icon')
check(has_virt_text(15, nil, 'DiverMarkdownTodo', 'overlay'), 'custom [-] todo icon')

-- Blockquotes: ▋ per level, cycling quote highlights.
check(has_virt_text(16, '▋', 'DiverMarkdownQuote1', 'overlay'), 'quote shows ▋')
check(has_virt_text(17, '▋', 'DiverMarkdownQuote2', 'overlay'), 'nested quote cycles the highlight')

-- Callouts: raw marker concealed, rendered label shown.
check(has_virt_text(18, 'Note', 'DiverMarkdownInfo', 'overlay'), '[!NOTE] renders its label')
check(has_virt_text(19, 'Warning', 'DiverMarkdownWarn', 'overlay'), '[!WARNING] renders its label')
check(has_conceal(18), 'callout raw marker is concealed')

-- Pipe table: header highlight, ━ delimiter, box borders.
check(has_hl(21, 'DiverMarkdownTableHead'), 'table header is highlighted')
check(has_hl(23, 'DiverMarkdownTableRow'), 'table body row is highlighted')
check(has_virt_text(22, '━', 'DiverMarkdownTableBorder', 'overlay'), 'delimiter row shows ━')
check(has_virt_lines(21, '┌'), 'table draws the top border')
check(has_virt_lines(23, '└'), 'table draws the bottom border')
check(has_conceal(21), 'table pipes are concealed')

-- Links: brackets concealed, text highlighted, domain icon inline.
check(has_conceal(25), 'link brackets are concealed')
check(has_hl(25, 'DiverMarkdownLink'), 'link text is highlighted')
check(has_virt_text(25, nil, 'DiverMarkdownLink', 'inline'), 'link gets an inline icon')

-- Inline code, ==highlight==, footnote, wiki link, HTML comment, email.
check(has_hl(25, 'DiverMarkdownCodeInline'), 'inline `code` is highlighted')
check(has_conceal(25), 'inline code backticks are concealed')
check(has_hl(25, 'DiverMarkdownInlineHighlight'), '==mark== is highlighted')
check(has_virt_text(26, '¹', 'DiverMarkdownLink', 'overlay'), 'footnote renders superscript')
check(has_virt_text(26, nil, 'DiverMarkdownWikiLink', 'inline'), 'wiki link gets its icon')
check(has_hl(26, 'DiverMarkdownHtmlComment'), 'HTML comment is highlighted')
check(has_hl(26, 'DiverMarkdownLink'), 'email autolink is highlighted')

-- Debounce: TextChanged schedules, it does not render synchronously.
api.nvim_buf_clear_namespace(buf, nsid, 0, -1)
api.nvim_exec_autocmds('TextChanged', { buffer = buf })
check(#marks_on(8) == 0, 'scheduled render is debounced, not immediate')
check(
    vim.wait(2000, function()
        return #marks_on(8) > 0
    end, 20),
    'debounced render fires and decorates'
)

-- File-size guard: a tiny limit skips rendering entirely.
render.setup({ max_file_size_mb = 0.000001 })
api.nvim_buf_clear_namespace(buf, nsid, 0, -1)
render.render(buf)
check(#marks_on(8) == 0, 'oversize buffer is not rendered')
render.setup({})
render.render(buf)
check(#marks_on(8) > 0, 'normal buffer renders again after the guard test')

-- enable() accepts the autocmd event table; disable() cleans up.
render.disable()
check(vim.b[buf].diver_markdown_render ~= true, 'disable() detaches')
check(#api.nvim_buf_get_extmarks(buf, nsid, 0, -1, {}) == 0, 'disable() clears extmarks')
check(render.enable({ buf = buf }) == true, 'enable() accepts the event table')
check(vim.b[buf].diver_markdown_render == true, 'enable() re-attaches')

api.nvim_buf_delete(buf, { force = true })
vim.fn.delete(path)

if #failures > 0 then
    print(('FAIL: %d passed, %d failed'):format(passed, #failures))
    for _, message in ipairs(failures) do
        print('  - ' .. message)
    end
    vim.cmd('cquit 1')
else
    print(('PASS: %d checks'):format(passed))
end
