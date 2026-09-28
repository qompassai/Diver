-- /qompassai/Diver/lua/research/ama.lua
-- Qompass AI Diver AMA Citation Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Formats reference lists in AMA Manual of Style, 11th edition.
--
-- Plain-language version: journals number every reference in the order it
-- is first cited, and each entry follows a strict pattern (authors, title,
-- journal, year, volume, pages, DOI). This module turns BibTeX entries into
-- those numbered lines and inserts the little raised citation numbers.
-- It does NOT abbreviate journal names for you — NLM abbreviations are an
-- external authority, so pass the abbreviated name in the journal field.
local M = {}

---Maximum BibTeX text parsed in one call (bytes).
local MAX_INPUT_BYTES = 200000
---Maximum entries parsed from one BibTeX blob.
local MAX_ENTRIES = 500
---Maximum characters kept per field value.
local MAX_FIELD_CHARS = 4000
---Maximum authors rendered before et al. logic applies.
local MAX_AUTHORS_LISTED = 6
---Maximum authors parsed per entry.
local MAX_AUTHORS_PARSED = 200

---@param s string
---@return string
local function trim(s)
    return s:match('^%s*(.-)%s*$') or ''
end

---Remove one layer of surrounding braces or quotes. Iterative, not recursive.
---@param s string
---@return string
local function strip_wrapping(s)
    s = trim(s)
    while #s >= 2 do
        local first = s:sub(1, 1)
        local last = s:sub(-1)
        if (first == '{' and last == '}') or (first == '"' and last == '"') then
            s = trim(s:sub(2, -2))
        else
            break
        end
    end
    return s
end

---Find the entry type and key at the head of a BibTeX entry chunk.
---@param chunk string
---@return string?, string?
local function head_type_key(chunk)
    local etype, key = chunk:match('^%s*@(%w+)%s*{%s*([^,%s}]+)')
    if etype then
        return etype:lower(), key
    end
    return nil, nil
end

---Split a BibTeX entry body into raw field assignments on top-level commas.
---@param body string
---@return string[]
local function split_fields(body)
    local fields = {}
    local depth = 0
    local start = 1
    local i = 1
    while i <= #body do
        local c = body:sub(i, i)
        if c == '{' then
            depth = depth + 1
        elseif c == '}' then
            depth = math.max(0, depth - 1)
        elseif c == ',' and depth == 0 then
            fields[#fields + 1] = body:sub(start, i - 1)
            start = i + 1
        end
        i = i + 1
    end
    local tail = trim(body:sub(start))
    if tail ~= '' then
        fields[#fields + 1] = tail
    end
    return fields
end

---Parse one `@type{key, field = value, ...}` chunk. Returns nil when the
---chunk is malformed; the caller skips it.
---@param chunk string
---@return table?
local function parse_entry(chunk)
    local etype, key = head_type_key(chunk)
    if not etype or not key then
        return nil
    end
    local entry = { type = etype, key = key, fields = {} }
    local body = chunk:match('^%s*@%w+%s*{%s*[^,%s}]+%s*,(.*)$')
    if not body then
        return entry
    end
    -- Drop the entry's closing brace: the last top-level } ends the entry.
    local depth = 0
    local cut = #body
    local i = 1
    while i <= #body do
        local c = body:sub(i, i)
        if c == '{' then
            depth = depth + 1
        elseif c == '}' then
            if depth == 0 then
                cut = i - 1
                break
            end
            depth = depth - 1
        end
        i = i + 1
    end
    for _, raw in ipairs(split_fields(body:sub(1, cut))) do
        local name, value = raw:match('^%s*([%w%-_]+)%s*=%s*(.-)%s*$')
        if name and value and value ~= '' then
            entry.fields[name:lower()] = strip_wrapping(value):sub(1, MAX_FIELD_CHARS)
        end
    end
    return entry
end

---Split a BibTeX text into entry chunks on top-level @...{...} spans.
---Malformed chunks are returned as-is and skipped by parse_entry.
---@param text string
---@return table[] entries
function M.parse_bibtex(text)
    assert(type(text) == 'string', 'parse_bibtex: text must be a string')
    if #text > MAX_INPUT_BYTES then
        text = text:sub(1, MAX_INPUT_BYTES)
    end
    local entries = {}
    local pos = 1
    while pos <= #text and #entries < MAX_ENTRIES do
        local at = text:find('@', pos, true)
        if not at then
            break
        end
        local open = text:find('{', at, true)
        if not open then
            break
        end
        local depth = 0
        local closed = false
        local i = open
        while i <= #text do
            local c = text:sub(i, i)
            if c == '{' then
                depth = depth + 1
            elseif c == '}' then
                depth = depth - 1
                if depth == 0 then
                    closed = true
                    break
                end
            end
            i = i + 1
        end
        if not closed then
            -- Unterminated entry: skip this '@' and keep scanning so one
            -- bad entry cannot swallow the rest of the buffer.
            pos = at + 1
        else
            local entry = parse_entry(text:sub(at, i))
            if entry then
                entries[#entries + 1] = entry
            end
            pos = i + 1
        end
    end
    return entries
end

---Split an author/editor field on the BibTeX ' and ' separator.
---@param s string
---@return string[]
local function split_names(s)
    local names = {}
    local count = 0
    for part in (s .. ' and '):gmatch('(.-)%s+and%s+') do
        count = count + 1
        if count > MAX_AUTHORS_PARSED then
            break
        end
        part = trim(part)
        if part ~= '' then
            names[#names + 1] = part
        end
    end
    return names
end

---Reduce given names to initials: 'John A.' -> 'JA', 'Mary-Kate' -> 'MK'.
---@param given string
---@return string
local function initials(given)
    local out = {}
    for token in given:gmatch('[%a]+') do
        out[#out + 1] = token:sub(1, 1):upper()
    end
    return table.concat(out)
end

---Clean one name part: strip a single layer of wrapping, then drop any
---remaining braces so hostile input cannot smuggle them into output.
---@param s string
---@return string
local function clean_part(s)
    s = strip_wrapping(s):gsub('[{}]', '')
    -- A quote left stranded at one end (e.g. '"Smith' from '"Smith, John"').
    s = s:gsub('^"+', ''):gsub('"+$', '')
    return s
end

---Format one author as 'Surname Initials'. Prefers the comma form
---('Smith, John A.'); for the space form it applies a documented heuristic:
---two tokens with an initials-like last token ('Smith JA', 'Smith J.A.')
---keep the first token as surname and the initials verbatim, otherwise the
---last token is the surname and any lowercase words before it are kept as
---particles ('Pieter van der Berg' becomes 'van der Berg P').
---@param name string
---@return string
function M.format_author(name)
    assert(type(name) == 'string', 'format_author: name must be a string')
    local surname, given = name:match('^%s*(.-)%s*,%s*(.-)%s*$')
    if surname and trim(surname) ~= '' then
        surname = clean_part(surname)
        local init = initials(clean_part(given or ''))
        if init ~= '' then
            return surname .. ' ' .. init
        end
        return surname
    end
    local tokens = {}
    for token in name:gmatch('%S+') do
        tokens[#tokens + 1] = clean_part(token)
    end
    if #tokens == 0 then
        return ''
    end
    if #tokens == 1 then
        return tokens[1]
    end
    if #tokens == 2 and tokens[2]:match('^[A-Z%.%-]+$') and #tokens[2] <= 5 then
        return tokens[1] .. ' ' .. tokens[2]:gsub('%.', ''):upper()
    end
    -- 'First von Last': trailing lowercase words belong to the surname.
    local last_idx = #tokens
    local first_idx = last_idx - 1
    while first_idx > 1 and tokens[first_idx]:match('^[a-z]') do
        first_idx = first_idx - 1
    end
    surname = table.concat(tokens, ' ', first_idx + 1, last_idx)
    local given_part = table.concat(tokens, ' ', 1, first_idx)
    local init = initials(given_part)
    if init ~= '' then
        return surname .. ' ' .. init
    end
    return surname
end

---Format an author list per AMA 11th: list all when 1-6 authors, first 3
---followed by 'et al.' when 7 or more.
---@param authors string[]
---@return string
function M.format_authors(authors)
    assert(type(authors) == 'table', 'format_authors: authors must be a table')
    local formatted = {}
    for i, name in ipairs(authors) do
        if i > MAX_AUTHORS_PARSED then
            break
        end
        local one = M.format_author(name)
        if one ~= '' then
            formatted[#formatted + 1] = one
        end
    end
    if #formatted == 0 then
        return ''
    end
    if #formatted <= MAX_AUTHORS_LISTED then
        return table.concat(formatted, ', ')
    end
    return table.concat(formatted, ', ', 1, 3) .. ', et al.'
end

---Collapse a DOI to its compact AMA form ('doi:10.xxxx/yyyy').
---@param doi string
---@return string
function M.normalize_doi(doi)
    assert(type(doi) == 'string', 'normalize_doi: doi must be a string')
    local compact = trim(doi):gsub('^https?://', ''):gsub('^doi%.org/', ''):gsub('^doi:%s*', '')
    return 'doi:' .. compact
end

---Render an integer as Unicode superscript digits ('12' -> '¹²').
---@param n integer
---@return string
function M.superscript(n)
    assert(type(n) == 'number' and n % 1 == 0 and n > 0, 'superscript: n must be a positive integer')
    local digits = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' }
    local out = {}
    for digit in tostring(n):gmatch('%d') do
        out[#out + 1] = digits[tonumber(digit) + 1]
    end
    return table.concat(out)
end

---@param fields table<string,string>
---@return string
local function pages_of(fields)
    local pages = fields.pages or fields.page or ''
    return pages:gsub('%-%-+', '-'):gsub('%s+', '')
end

---@param fields table<string,string>
---@return string
local function year_of(fields)
    return (fields.year or fields.date or ''):match('%d%d%d%d') or ''
end

---Format a journal article per AMA 11th. The journal field must already
---carry the NLM abbreviation; this function does not abbreviate.
---@param entry table
---@return string
function M.format_article(entry)
    local f = entry.fields
    local authors = M.format_authors(split_names(f.author or ''))
    local parts = {}
    if authors ~= '' then
        parts[#parts + 1] = authors .. '.'
    end
    if f.title and f.title ~= '' then
        parts[#parts + 1] = trim(f.title:gsub('[{}]', '')) .. '.'
    end
    local pub = {}
    if f.journal and f.journal ~= '' then
        pub[#pub + 1] = trim(f.journal:gsub('[{}]', '')) .. '.'
    end
    local year = year_of(f)
    local vol_issue = f.volume or ''
    if f.number and f.number ~= '' then
        vol_issue = vol_issue .. '(' .. f.number .. ')'
    end
    local pages = pages_of(f)
    local tail = year
    if vol_issue ~= '' then
        tail = tail .. ';' .. vol_issue
    end
    if pages ~= '' then
        tail = tail .. ':' .. pages
    end
    if tail ~= '' then
        pub[#pub + 1] = tail .. '.'
    end
    if #pub > 0 then
        parts[#parts + 1] = table.concat(pub, ' ')
    end
    if f.doi and f.doi ~= '' then
        parts[#parts + 1] = M.normalize_doi(f.doi)
    elseif f.url and f.url ~= '' then
        parts[#parts + 1] = 'Accessed ' .. os.date('%B %d, %Y') .. '. ' .. trim(f.url)
    end
    return table.concat(parts, ' ')
end

---Format a book per AMA 11th.
---@param entry table
---@return string
function M.format_book(entry)
    local f = entry.fields
    local authors = M.format_authors(split_names(f.author or f.editor or ''))
    local parts = {}
    if authors ~= '' then
        parts[#parts + 1] = authors .. '.'
    end
    if f.title and f.title ~= '' then
        parts[#parts + 1] = trim(f.title:gsub('[{}]', '')) .. '.'
    end
    local pub = {}
    if f.edition and f.edition ~= '' then
        pub[#pub + 1] = trim(f.edition) .. ' ed.'
    end
    if f.publisher and f.publisher ~= '' then
        pub[#pub + 1] = trim(f.publisher)
    end
    local year = year_of(f)
    if year ~= '' then
        pub[#pub + 1] = year
    end
    if #pub > 0 then
        parts[#parts + 1] = table.concat(pub, '; ') .. '.'
    end
    return table.concat(parts, ' ')
end

---Format a book chapter per AMA 11th.
---@param entry table
---@return string
function M.format_chapter(entry)
    local f = entry.fields
    local authors = M.format_authors(split_names(f.author or ''))
    local parts = {}
    if authors ~= '' then
        parts[#parts + 1] = authors .. '.'
    end
    if f.title and f.title ~= '' then
        parts[#parts + 1] = trim(f.title:gsub('[{}]', '')) .. '.'
    end
    local booktitle = f.booktitle and trim(f.booktitle:gsub('[{}]', '')) or ''
    local editors = M.format_authors(split_names(f.editor or ''))
    local in_line = 'In: '
    if editors ~= '' then
        in_line = in_line .. editors .. ', eds. '
    end
    in_line = in_line .. booktitle .. '.'
    if booktitle ~= '' then
        parts[#parts + 1] = in_line
    end
    local pub = {}
    if f.publisher and f.publisher ~= '' then
        pub[#pub + 1] = trim(f.publisher)
    end
    local year = year_of(f)
    if year ~= '' then
        pub[#pub + 1] = year
    end
    local pages = pages_of(f)
    if pages ~= '' then
        pub[#pub + 1] = 'p' .. pages
    end
    if #pub > 0 then
        parts[#parts + 1] = table.concat(pub, '; ') .. '.'
    end
    return table.concat(parts, ' ')
end

---Format a preprint (arXiv, medRxiv, bioRxiv) per AMA 11th.
---@param entry table
---@return string
function M.format_preprint(entry)
    local f = entry.fields
    local authors = M.format_authors(split_names(f.author or ''))
    local parts = {}
    if authors ~= '' then
        parts[#parts + 1] = authors .. '.'
    end
    if f.title and f.title ~= '' then
        parts[#parts + 1] = trim(f.title:gsub('[{}]', '')) .. '.'
    end
    local server = f.journal or f.publisher or f.eprinttype or 'Preprint'
    local line = trim(server:gsub('[{}]', ''))
    local year = year_of(f)
    if year ~= '' then
        line = line .. '. ' .. year
    end
    local id = f.eprint or ''
    if id ~= '' then
        line = line .. ':' .. trim(id)
    end
    parts[#parts + 1] = line .. '.'
    if f.doi and f.doi ~= '' then
        parts[#parts + 1] = M.normalize_doi(f.doi)
    elseif f.url and f.url ~= '' then
        parts[#parts + 1] = 'Accessed ' .. os.date('%B %d, %Y') .. '. ' .. trim(f.url)
    end
    return table.concat(parts, ' ')
end

---Dispatch one parsed entry to its AMA 11th formatter.
---@param entry table
---@return string
function M.format(entry)
    assert(type(entry) == 'table', 'format: entry must be a table')
    local etype = entry.type or 'misc'
    if etype == 'article' then
        return M.format_article(entry)
    elseif etype == 'book' then
        return M.format_book(entry)
    elseif etype == 'incollection' or etype == 'inbook' or etype == 'inproceedings' then
        return M.format_chapter(entry)
    elseif etype == 'online' or etype == 'electronic' or etype == 'unpublished' then
        return M.format_preprint(entry)
    end
    return M.format_article(entry)
end

---Format entries into a numbered reference list, in citation order.
---@param entries table[]
---@return string[] lines like '1. Author AA. Title. ...'
function M.format_all(entries)
    assert(type(entries) == 'table', 'format_all: entries must be a table')
    local lines = {}
    for i, entry in ipairs(entries) do
        if i > MAX_ENTRIES then
            break
        end
        lines[#lines + 1] = i .. '. ' .. M.format(entry)
    end
    return lines
end

---Parse BibTeX text and return the numbered AMA reference lines.
---@param text string
---@return string[]
function M.parse_and_format(text)
    return M.format_all(M.parse_bibtex(text))
end

---Show lines in a scratch buffer for review before inserting.
---@param title string
---@param lines string[]
local function show_scratch(title, lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
    vim.cmd('botright split')
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_buf_set_name(bufnr, title)
end

function M.setup()
    vim.api.nvim_create_user_command('AmaFormat', function()
        local bufnr = vim.api.nvim_get_current_buf()
        local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
        local lines = M.parse_and_format(text)
        if #lines == 0 then
            vim.notify('AmaFormat: no BibTeX entries found in buffer', vim.log.levels.WARN)
            return
        end
        show_scratch('AMA References', lines)
        vim.notify(('AmaFormat: %d reference(s) formatted'):format(#lines), vim.log.levels.INFO)
    end, { desc = 'Format BibTeX entries in buffer as AMA 11th references' })

    vim.api.nvim_create_user_command('AmaCite', function(opts)
        local from, to = opts.args:match('^(%d+)%s*%-?%s*(%d*)$')
        if not from then
            vim.notify('Usage: AmaCite {n} or AmaCite {from}-{to}', vim.log.levels.ERROR)
            return
        end
        local from_num = tonumber(from)
        local to_num = to == '' and from_num or tonumber(to)
        if not from_num or from_num < 1 or not to_num or to_num < from_num then
            vim.notify('Usage: AmaCite {n} or AmaCite {from}-{to} with positive numbers', vim.log.levels.ERROR)
            return
        end
        local cite = M.superscript(from_num)
        if to_num ~= from_num then
            cite = cite .. '-' .. M.superscript(to_num)
        end
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        vim.api.nvim_set_current_line(line:sub(1, col) .. cite .. line:sub(col + 1))
        vim.api.nvim_win_set_cursor(0, { row, col + #cite })
    end, { nargs = 1, desc = 'Insert AMA superscript citation number(s)' })
end

return M
