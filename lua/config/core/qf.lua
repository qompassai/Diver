-- /qompassai/Diver/lua/config/core/qf.lua
-- Native quickfix/location lists: stable IDs, bounded edits, public highlighting APIs.
-- SPDX-License-Identifier: Apache-2.0
local api, fn = vim.api, vim.fn
local M = {}
local ITEMS_MAX = 20000
local HIGHLIGHTS_MAX = 4096

local function notify(message)
    vim.notify(message, vim.log.levels.WARN, { title = 'Quickfix' })
end

---@param kind? 'qf'|'loc'
---@return table target
function M.target(kind)
    local win = api.nvim_get_current_win()
    local info = fn.getwininfo(win)[1]
    kind = kind or (info and info.loclist == 1 and 'loc' or 'qf')
    assert(kind == 'qf' or kind == 'loc')
    if kind == 'loc' and info and info.loclist == 1 then
        local owner = fn.getloclist(win, { filewinid = 0 }).filewinid
        if owner and owner ~= 0 then
            win = owner
        end
    end
    return { kind = kind, win = win }
end

function M.get(target, what)
    if not api.nvim_win_is_valid(target.win) then
        return nil, 'List window closed'
    end
    if target.kind == 'loc' then
        return fn.getloclist(target.win, what)
    end
    return fn.getqflist(what)
end

local function set(target, action, what)
    if not api.nvim_win_is_valid(target.win) then
        return nil, 'List window closed'
    end
    local result
    if target.kind == 'loc' then
        result = fn.setloclist(target.win, {}, action, what)
    else
        result = fn.setqflist({}, action, what)
    end
    if result ~= 0 then
        return nil, 'Unable to update list'
    end
    return true
end

function M.snapshot(target)
    local meta, err = M.get(target, { size = 0, id = 0, changedtick = 0 })
    if not meta then
        return nil, err
    end
    if meta.size > ITEMS_MAX then
        return nil, 'List exceeds 20000 entries; narrow its source'
    end
    return M.get(target, { all = 0 })
end

local function current(target, saved)
    local now = M.get(target, { id = 0, changedtick = 0 })
    return now and now.id == saved.id and now.changedtick == saved.changedtick
end

local function execute(target, command)
    if not api.nvim_win_is_valid(target.win) then
        return
    end
    local destination
    local ok, err = pcall(api.nvim_win_call, target.win, function()
        vim.cmd(command)
        destination = api.nvim_get_current_win()
    end)
    if not ok then
        notify(tostring(err))
    elseif command:match('^cc %d+$') or command:match('^ll %d+$') then
        if destination and api.nvim_win_is_valid(destination) then
            api.nvim_set_current_win(destination)
        end
    elseif command == 'copen' or command == 'lopen' then
        local info = M.get(target, { winid = 0 })
        if info and info.winid ~= 0 then
            api.nvim_set_current_win(info.winid)
        end
    end
end

function M.open(kind)
    local target = M.target(kind)
    execute(target, kind == 'loc' and 'lopen' or 'copen')
end

---Commit transformations as a new history entry so colder/lolder restores the source.
local function commit(target, saved, items, label)
    if not current(target, saved) then
        return nil, 'List changed; invoke again'
    end
    return set(target, ' ', {
        items = items,
        title = (saved.title or '') .. ' | ' .. label,
        context = saved.context,
    })
end

function M.filter(target, pattern, exclude)
    target = target or M.target()
    local saved, err = M.snapshot(target)
    if not saved then
        return nil, err
    end
    if type(pattern) ~= 'string' or #pattern > 4096 then
        return nil, 'Invalid filter'
    end
    local ok, regex = pcall(vim.regex, pattern)
    if not ok then
        return nil, tostring(regex)
    end
    local items = {}
    for _, item in ipairs(saved.items) do
        local name = item.bufnr > 0 and api.nvim_buf_get_name(item.bufnr) or ''
        local matched = regex:match_str(name .. ' ' .. (item.text or '')) ~= nil
        if matched ~= (exclude == true) then
            items[#items + 1] = item
        end
    end
    return commit(target, saved, items, exclude and 'exclude' or 'filter')
end

function M.remove(target, first, last)
    target = target or M.target()
    local saved, err = M.snapshot(target)
    if not saved then
        return nil, err
    end
    first, last = first or saved.idx, last or first or saved.idx
    if first < 1 or last < first or last > #saved.items then
        return nil, 'Invalid entry range'
    end
    local items = {}
    for index, item in ipairs(saved.items) do
        if index < first or index > last then
            items[#items + 1] = item
        end
    end
    return commit(target, saved, items, 'remove')
end

function M.transform(target, operation)
    local saved, err = M.snapshot(target)
    if not saved then
        return nil, err
    end
    local items, seen = {}, {}
    for _, item in ipairs(saved.items) do
        local key = vim.json.encode({ item.bufnr, item.lnum, item.col, item.text, item.type })
        if operation ~= 'unique' or not seen[key] then
            items[#items + 1] = item
        end
        seen[key] = true
    end
    if operation == 'sort' then
        table.sort(items, function(a, b)
            local an = a.bufnr > 0 and api.nvim_buf_get_name(a.bufnr) or ''
            local bn = b.bufnr > 0 and api.nvim_buf_get_name(b.bufnr) or ''
            if an ~= bn then
                return an < bn
            end
            if a.lnum ~= b.lnum then
                return a.lnum < b.lnum
            end
            if a.col ~= b.col then
                return a.col < b.col
            end
            return (a.text or '') < (b.text or '')
        end)
    elseif operation == 'reverse' then
        for index = 1, math.floor(#items / 2) do
            local other = #items - index + 1
            items[index], items[other] = items[other], items[index]
        end
    elseif operation ~= 'unique' then
        return nil, 'Unknown list transformation'
    end
    return commit(target, saved, items, operation)
end

local function report(ok, err)
    if not ok and err then
        notify(err)
    end
end

local function prompt_filter(target, exclude)
    local saved, err = M.snapshot(target)
    if not saved then
        notify(err)
        return
    end
    vim.ui.input(
        { prompt = exclude and 'Exclude Vim regex: ' or 'Keep Vim regex: ' },
        function(pattern)
            if pattern == nil then
                return
            end
            if not current(target, saved) then
                notify('List changed; invoke filter again')
                return
            end
            report(M.filter(target, pattern, exclude))
        end
    )
end

function M.history(target)
    target = target or M.target()
    local info = M.get(target, { nr = '$' })
    if not info then
        return
    end
    local items = {}
    for nr = 1, math.min(info.nr, 100) do
        local list = M.get(target, { nr = nr, id = 0, title = 0, size = 0 })
        items[#items + 1] = list
    end
    vim.ui.select(items, {
        prompt = 'List history:',
        format_item = function(item)
            return ('%d: %s (%d)'):format(item.nr, item.title, item.size)
        end,
    }, function(choice)
        if not choice then
            return
        end
        local latest = M.get(target, { nr = choice.nr, id = 0 })
        local active = M.get(target, { nr = 0 })
        if not latest or not active or latest.id ~= choice.id then
            notify('History changed')
            return
        end
        local delta = choice.nr - active.nr
        if delta ~= 0 then
            execute(
                target,
                (target.kind == 'loc' and 'l' or 'c')
                    .. (delta > 0 and 'newer ' or 'older ')
                    .. math.abs(delta)
            )
        end
    end)
end

function M.preview(target, index)
    target = target or M.target()
    local saved, err = M.snapshot(target)
    if not saved then
        notify(err)
        return
    end
    local item = saved.items[index or saved.idx]
    if not item or item.bufnr <= 0 or item.lnum <= 0 then
        notify('Entry has no file position')
        return
    end
    local name = api.nvim_buf_get_name(item.bufnr)
    if name == '' then
        notify('Entry has no filename')
        return
    end
    local ok, message = pcall(api.nvim_cmd, {
        cmd = 'pedit',
        args = { name },
        magic = { file = false, bar = false },
    }, {})
    if not ok then
        notify(tostring(message))
        return
    end
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        if vim.wo[win].previewwindow then
            local row = math.min(item.lnum, api.nvim_buf_line_count(api.nvim_win_get_buf(win)))
            api.nvim_win_set_cursor(win, { math.max(row, 1), math.max((item.col or 1) - 1, 0) })
            break
        end
    end
end

function M.transfer(target)
    local saved, err = M.snapshot(target)
    if not saved then
        return nil, err
    end
    local other = { kind = target.kind == 'qf' and 'loc' or 'qf', win = target.win }
    if other.kind == 'loc' then
        local info = fn.getwininfo(other.win)[1]
        if info and info.quickfix == 1 then
            local previous = fn.win_getid(fn.winnr('#'))
            if previous == 0 or fn.getwininfo(previous)[1].quickfix == 1 then
                return nil, 'Focus a source window before copying to its location list'
            end
            other.win = previous
        end
    end
    return set(other, ' ', { items = saved.items, title = saved.title, context = saved.context })
end

---Batch commands are typed explicitly by the user, and run only against the captured list.
local function batch(target, files)
    local saved, err = M.snapshot(target)
    if not saved then
        notify(err)
        return
    end
    vim.ui.input(
        { prompt = files and 'Ex command per file: ' or 'Ex command per entry: ' },
        function(command)
            if not command or command == '' then
                return
            end
            if not current(target, saved) then
                notify('List changed; invoke batch again')
                return
            end
            if #command > 4096 then
                notify('Command exceeds 4096 bytes')
                return
            end
            execute(
                target,
                (target.kind == 'loc' and 'l' or 'c') .. (files and 'fdo ' or 'do ') .. command
            )
        end
    )
end

---Pick a valid entry while retaining its list ID across the UI callback.
function M.pick(target)
    local saved, err = M.snapshot(target)
    if not saved then
        notify(err)
        return
    end
    local choices = {}
    for index, item in ipairs(saved.items) do
        choices[#choices + 1] = { index = index, item = item }
    end
    local function select(items)
        vim.ui.select(items, {
            prompt = 'List entry:',
            format_item = function(entry)
                local item = entry.item
                local name = item.bufnr > 0 and api.nvim_buf_get_name(item.bufnr) or ''
                return ('%d %s:%d:%d %s')
                    :format(entry.index, name, item.lnum, item.col, item.text)
                    :sub(1, 2048)
                    :gsub('[%c]', ' ')
            end,
        }, function(choice)
            if not choice then
                return
            end
            if not current(target, saved) then
                notify('List changed; select again')
                return
            end
            execute(target, (target.kind == 'loc' and 'll ' or 'cc ') .. choice.index)
        end)
    end
    if #choices <= 200 then
        select(choices)
        return
    end
    vim.ui.input({ prompt = 'Entry text filter (literal, first 200): ' }, function(query)
        if query == nil then
            return
        end
        if not current(target, saved) then
            notify('List changed; select again')
            return
        end
        local matches = {}
        for _, entry in ipairs(choices) do
            if entry.item.text:find(query, 1, true) then
                matches[#matches + 1] = entry
            end
            if #matches == 200 then
                break
            end
        end
        select(matches)
    end)
end

function M.load_file(target)
    local saved = M.get(target, { id = 0, changedtick = 0 })
    vim.ui.input({ prompt = 'Error file (uses errorformat): ', completion = 'file' }, function(path)
        if not path or path == '' then
            return
        end
        if not saved or not current(target, saved) then
            notify('List changed; load again')
            return
        end
        path = fn.fnamemodify(fn.expand(path), ':p')
        local stat = vim.uv.fs_stat(path)
        if not stat or stat.type ~= 'file' or stat.size > 8 * 1024 * 1024 then
            notify('Choose a regular error file up to 8 MiB')
            return
        end
        local ok, lines = pcall(fn.readfile, path, '', ITEMS_MAX + 1)
        if not ok then
            notify(tostring(lines))
            return
        end
        if #lines > ITEMS_MAX then
            notify('Error file exceeds 20000 lines')
            return
        end
        local efm = api.nvim_win_call(target.win, function()
            return vim.bo.errorformat
        end)
        report(set(target, ' ', { lines = lines, efm = efm, title = path }))
    end)
end

function M.load_buffer(target)
    local buffer = api.nvim_win_get_buf(target.win)
    local size = api.nvim_buf_get_offset(buffer, api.nvim_buf_line_count(buffer))
    if size < 0 or size > 8 * 1024 * 1024 or api.nvim_buf_line_count(buffer) > ITEMS_MAX then
        notify('Buffer exceeds list input budget')
        return
    end
    report(set(target, ' ', {
        lines = api.nvim_buf_get_lines(buffer, 0, -1, false),
        efm = vim.bo[buffer].errorformat,
        title = 'Buffer: ' .. api.nvim_buf_get_name(buffer),
    }))
end

---Export file:line:column:text records consumable with errorformat=%f:%l:%c:%m.
function M.write_file(target)
    local saved, err = M.snapshot(target)
    if not saved then
        notify(err)
        return
    end
    vim.ui.input({ prompt = 'Write new error file: ', completion = 'file' }, function(path)
        if not path or path == '' then
            return
        end
        local lines, bytes = {}, 0
        for _, item in ipairs(saved.items) do
            local name = item.bufnr > 0 and api.nvim_buf_get_name(item.bufnr) or ''
            if name:find('[\r\n]') then
                notify('Cannot export newline filenames to a line protocol')
                return
            end
            local line = ('%s:%d:%d:%s\n'):format(
                name,
                item.lnum,
                item.col,
                item.text:gsub('[\r\n]', ' ')
            )
            bytes = bytes + #line
            if bytes > 8 * 1024 * 1024 then
                notify('Export exceeds 8 MiB')
                return
            end
            lines[#lines + 1] = line
        end
        path = fn.fnamemodify(fn.expand(path), ':p')
        local fd, open_error = vim.uv.fs_open(path, 'wx', 384)
        if not fd then
            notify('Create error file: ' .. tostring(open_error))
            return
        end
        local written, write_error = vim.uv.fs_write(fd, table.concat(lines), 0)
        local closed, close_error = vim.uv.fs_close(fd)
        if written ~= bytes or not closed then
            notify('Incomplete export: ' .. tostring(write_error or close_error))
            return
        end
        vim.notify('Wrote ' .. path)
    end)
end

function M.run(action, kind)
    local target = M.target(kind)
    local prefix = target.kind == 'loc' and 'l' or 'c'
    local commands = {
        close = 'close',
        first = 'first',
        last = 'last',
        newer = 'newer',
        next = 'next',
        next_file = 'nfile',
        older = 'older',
        open = 'open',
        previous = 'previous',
        previous_file = 'pfile',
    }
    if commands[action] then
        execute(target, prefix .. commands[action])
        return
    end
    if action == 'filter' or action == 'exclude' then
        prompt_filter(target, action == 'exclude')
    elseif action == 'pick' then
        M.pick(target)
    elseif action == 'load_file' then
        M.load_file(target)
    elseif action == 'load_buffer' then
        M.load_buffer(target)
    elseif action == 'write_file' then
        M.write_file(target)
    elseif action == 'history' then
        M.history(target)
    elseif action == 'preview' then
        M.preview(target)
    elseif action == 'batch_entries' or action == 'batch_files' then
        batch(target, action == 'batch_files')
    elseif action == 'transfer' then
        report(M.transfer(target))
    elseif action == 'sort' or action == 'reverse' or action == 'unique' then
        report(M.transform(target, action))
    elseif action == 'clear' then
        local saved, err = M.snapshot(target)
        if saved then
            report(commit(target, saved, {}, 'clear'))
        else
            notify(err)
        end
    elseif action == 'toggle' then
        local info = M.get(target, { winid = 0 })
        if info then
            execute(target, prefix .. (info.winid ~= 0 and 'close' or 'open'))
        end
    elseif action == 'actions' then
        M.actions(target)
    else
        notify('Unknown quickfix action: ' .. tostring(action))
    end
end

M.entries = {
    { 'a', 'actions', 'Action menu' },
    { 'b', 'batch_files', 'Batch Ex command per file' },
    { 'c', 'close', 'Close list' },
    { 'd', 'batch_entries', 'Do Ex command per entry' },
    { 'e', 'exclude', 'Exclude matches' },
    { 'f', 'filter', 'Filter matches' },
    { 'g', 'pick', 'Go to selected entry' },
    { 'h', 'history', 'History' },
    { 'i', 'load_file', 'Import error file using errorformat' },
    { 'j', 'next_file', 'Next file' },
    { 'k', 'previous_file', 'Previous file' },
    { 'm', 'load_buffer', 'Make list from buffer using errorformat' },
    { 'n', 'next', 'Next entry' },
    { 'o', 'open', 'Open list' },
    { 'p', 'previous', 'Previous entry' },
    { 'r', 'reverse', 'Reverse entries' },
    { 's', 'sort', 'Sort by file and position' },
    { 't', 'toggle', 'Toggle list' },
    { 'u', 'unique', 'Unique entries' },
    { 'v', 'preview', 'Preview entry' },
    { 'w', 'write_file', 'Write new error file' },
    { 'x', 'clear', 'Clear into new history entry' },
    { 'y', 'transfer', 'Copy to other list type' },
    { 'z', 'last', 'Last entry' },
    { '[', 'older', 'Older history' },
    { ']', 'newer', 'Newer history' },
    { '0', 'first', 'First entry' },
}

function M.actions(target)
    target = target or M.target()
    local entries = {}
    for _, entry in ipairs(M.entries) do
        if entry[2] ~= 'actions' then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        return a[3] < b[3]
    end)
    vim.ui.select(entries, {
        prompt = target.kind .. ' actions:',
        format_item = function(e)
            return e[3]
        end,
    }, function(choice)
        if choice and api.nvim_win_is_valid(target.win) then
            api.nvim_win_call(target.win, function()
                M.run(choice[2], target.kind)
            end)
        end
    end)
end

local function row_valid(bufnr, lnum)
    return api.nvim_buf_is_loaded(bufnr) and lnum >= 1 and lnum <= api.nvim_buf_line_count(bufnr)
end

function M.buf_get_ts_highlights(bufnr, lnum)
    if not row_valid(bufnr, lnum) then
        return {}
    end
    if api.nvim_buf_get_offset(bufnr, api.nvim_buf_line_count(bufnr)) > 2 * 1024 * 1024 then
        return {}
    end
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, nil, { error = false })
    if not ok or not parser then
        return {}
    end
    local trees = parser:parse()
    local query = vim.treesitter.query.get(parser:lang(), 'highlights')
    if not query or not trees or not trees[1] then
        return {}
    end
    local out, row = {}, lnum - 1
    for id, node in query:iter_captures(trees[1]:root(), bufnr, row, row + 1) do
        if #out >= HIGHLIGHTS_MAX then
            break
        end
        local sr, sc, er, ec = node:range()
        if sr <= row and er >= row and not (er == row and ec == 0) then
            out[#out + 1] = {
                sr < row and 0 or sc,
                er > row and -1 or ec,
                '@' .. query.captures[id] .. '.' .. parser:lang(),
            }
        end
    end
    return out
end

function M.buf_get_lsp_highlights(bufnr, lnum)
    if not row_valid(bufnr, lnum) then
        return {}
    end
    local line = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ''
    local out, seen = {}, {}
    for col = 0, math.min(#line, 1024) do
        local tokens = vim.lsp.semantic_tokens.get_at_pos(bufnr, lnum - 1, col) or {}
        for _, token in ipairs(tokens) do
            local key = ('%d:%d:%d:%s'):format(
                token.client_id,
                token.start_col,
                token.end_col,
                token.type
            )
            if not seen[key] and #out < HIGHLIGHTS_MAX then
                seen[key] = true
                local start = token.line < lnum - 1 and 0 or token.start_col
                local finish = token.end_line > lnum - 1 and -1 or token.end_col
                local suffix = '.' .. vim.bo[bufnr].filetype
                out[#out + 1] = { start, finish, '@lsp.type.' .. token.type .. suffix, 0 }
                for _, modifier in ipairs(vim.tbl_keys(token.modifiers or {})) do
                    if #out + 2 > HIGHLIGHTS_MAX then
                        break
                    end
                    out[#out + 1] = { start, finish, '@lsp.mod.' .. modifier .. suffix, 1 }
                    out[#out + 1] = {
                        start,
                        finish,
                        '@lsp.typemod.' .. token.type .. '.' .. modifier .. suffix,
                        2,
                    }
                end
            end
        end
    end
    return out
end

function M.get_heuristic_ts_highlights(item, line)
    if #line > 16384 or not item.bufnr or not api.nvim_buf_is_valid(item.bufnr) then
        return {}
    end
    local lang = vim.treesitter.language.get_lang(vim.bo[item.bufnr].filetype)
    if not lang then
        return {}
    end
    local ok, parser = pcall(vim.treesitter.get_string_parser, line, lang)
    if not ok or not parser then
        return {}
    end
    local query = vim.treesitter.query.get(lang, 'highlights')
    if not query then
        return {}
    end
    local trees = parser:parse()
    if not trees or not trees[1] then
        return {}
    end
    local out = {}
    for id, node in query:iter_captures(trees[1]:root(), line) do
        if #out == HIGHLIGHTS_MAX then
            break
        end
        local _, sc, er, ec = node:range()
        out[#out + 1] = { sc, er > 0 and -1 or ec, '@' .. query.captures[id] .. '.' .. lang }
    end
    return out
end

function M.set_highlight_groups()
    for name, link in pairs({
        QuickFixFilename = 'Directory',
        QuickFixFilenameInvalid = 'Comment',
        QuickFixHeaderHard = 'Delimiter',
        QuickFixHeaderSoft = 'Comment',
        QuickFixLineNr = 'LineNr',
        QuickFixTextInvalid = 'Comment',
    }) do
        api.nvim_set_hl(0, name, { link = link, default = true })
    end
end

function M.setup()
    M.set_highlight_groups()
    local group = api.nvim_create_augroup('DiverQuickfix', { clear = true })
    api.nvim_create_autocmd('ColorScheme', { group = group, callback = M.set_highlight_groups })
end
return M
