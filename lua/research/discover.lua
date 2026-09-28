-- /qompassai/Diver/lua/research/discover.lua
-- Qompass AI Diver Research Discovery Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Finds papers without leaving Neovim and shells out to the arXiv CLI
-- tools installed on this machine — but only the ones that are actually
-- there, with only the flags they really accept (verified 2026-09-28).
--
-- Plain-language version: type :ArxivFind followed by words and you get a
-- list of matching preprints in a scratch buffer. Enter opens the PDF,
-- y copies the link, b grabs the BibTeX. The other commands wrap the
-- helper programs: doi2bib and arxiv2bib turn identifiers into BibTeX,
-- arxiv-collector bundles a LaTeX project for arXiv submission, and
-- arxiv_latex_cleaner tidies the sources first.
local M = {}

---arXiv API endpoint.
local ARXIV_API = 'https://export.arxiv.org/api/query'
---Default results per search.
local DEFAULT_MAX_RESULTS = 10
---Hard cap on results per search (the API is a shared resource).
local MAX_RESULTS_CAP = 50
---curl timeout for API searches (seconds).
local SEARCH_TIMEOUT = 25
---curl timeout for BibTeX fetches (seconds).
local BIB_TIMEOUT = 30
---Timeout for local packaging/cleaning runs (seconds).
local BUILD_TIMEOUT = 120
---Maximum feed XML parsed in one call (bytes).
local MAX_FEED_BYTES = 2000000
---Maximum entries taken from one feed.
local MAX_FEED_ENTRIES = 50

---CLI tools this module wraps. `flag_note` records the verified
---invocation shape; `broken` marks tools observed to crash.
---Verified against the real binaries on 2026-09-28.
local TOOLS = {
    {
        name = 'arxiv2bib',
        purpose = 'arXiv IDs to BibTeX on stdout',
        flag_note = 'arxiv2bib [arxiv_id ...]; no args reads stdin',
    },
    {
        name = 'doi2bib',
        purpose = 'DOI to BibTeX on stdout',
        flag_note = 'doi2bib 10.xxxx/yyyy [-i in] [-o out] [--abstract]',
    },
    {
        name = 'arxiv-collector',
        purpose = 'bundle a LaTeX project into an arXiv submission tarball',
        flag_note = 'arxiv-collector [base_name] [--dest DEST]',
    },
    {
        name = 'arxiv_latex_cleaner',
        purpose = 'clean LaTeX sources before arXiv submission',
        flag_note = 'arxiv_latex_cleaner input_folder [--keep_bib]',
    },
    {
        name = 'quickbib',
        purpose = 'identifier to BibTeX (UNUSABLE: core dumps on --help, 2026-09-28)',
        flag_note = 'present but crashes; not wired to any command',
        broken = true,
    },
}

---@param exe string
---@return boolean
local function available(exe)
    return vim.fn.executable(exe) == 1
end

---@param text string
---@return string
local function clean_text(text)
    return (text:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1'))
end

---Extract one <tag>value</tag> pair from an entry chunk (narrow on purpose).
---@param chunk string
---@param tag string
---@return string?
local function tag_value(chunk, tag)
    return chunk:match('<' .. tag .. '[^>]*>(.-)</' .. tag .. '>')
end

---Parse one <entry> chunk of an arXiv Atom feed into a result table.
---@param chunk string
---@return table?
local function parse_entry(chunk)
    local id_url = tag_value(chunk, 'id')
    if not id_url then
        return nil
    end
    local id = clean_text(id_url:gsub('^https?://arxiv%.org/abs/', ''))
    if id == '' then
        return nil
    end
    local authors = {}
    for name in chunk:gmatch('<author>%s*<name>(.-)</name>%s*</author>') do
        authors[#authors + 1] = clean_text(name)
        if #authors >= 12 then
            break
        end
    end
    local title = tag_value(chunk, 'title')
    local published = tag_value(chunk, 'published') or ''
    local summary = tag_value(chunk, 'summary') or ''
    return {
        id = id,
        title = title and clean_text(title) or '(no title)',
        authors = authors,
        published = clean_text(published):sub(1, 10),
        summary = clean_text(summary):sub(1, 600),
        abs_url = 'https://arxiv.org/abs/' .. id,
        pdf_url = 'https://arxiv.org/pdf/' .. id,
    }
end

---Parse arXiv Atom XML into a bounded list of results. Malformed entries
---are skipped; the whole feed is capped by size and entry count.
---@param xml string
---@return table[] results
function M.parse_feed(xml)
    assert(type(xml) == 'string', 'parse_feed: xml must be a string')
    if #xml > MAX_FEED_BYTES then
        xml = xml:sub(1, MAX_FEED_BYTES)
    end
    local results = {}
    for chunk in xml:gmatch('<entry>(.-)</entry>') do
        if #results >= MAX_FEED_ENTRIES then
            break
        end
        local entry = parse_entry(chunk)
        if entry then
            results[#results + 1] = entry
        end
    end
    return results
end

---Search arXiv via the public Atom API. The callback receives (results, err).
---@param query string
---@param opts table? { max_results = number }
---@param on_done fun(results: table[]?, err: string?)
function M.search(query, opts, on_done)
    assert(type(query) == 'string' and query ~= '', 'search: query must be a non-empty string')
    assert(type(on_done) == 'function', 'search: on_done must be a function')
    opts = opts or {}
    local max_results = opts.max_results or DEFAULT_MAX_RESULTS
    if max_results < 1 then
        max_results = 1
    end
    if max_results > MAX_RESULTS_CAP then
        max_results = MAX_RESULTS_CAP
    end
    local argv = {
        'curl',
        '-sS',
        '--max-time',
        tostring(SEARCH_TIMEOUT),
        '--get',
        '--data-urlencode',
        'search_query=' .. query,
        '--data-urlencode',
        'start=0',
        '--data-urlencode',
        'max_results=' .. max_results,
        '--data-urlencode',
        'sortBy=submittedDate',
        '--data-urlencode',
        'sortOrder=descending',
        ARXIV_API,
    }
    vim.system(argv, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                on_done(nil, clean_text(result.stderr or 'arXiv query failed'))
                return
            end
            local ok, results = pcall(M.parse_feed, result.stdout or '')
            if not ok then
                on_done(nil, 'could not parse arXiv response')
                return
            end
            on_done(results, nil)
        end)
    end)
end

---Render one result as scratch-buffer lines.
---@param result table
---@param index integer
---@return string[]
local function result_lines(result, index)
    local lines = {
        ('%d. %s'):format(index, result.title),
        ('   %s  |  %s  |  %s'):format(
            table.concat(result.authors, ', '),
            result.published,
            result.id
        ),
    }
    if result.summary ~= '' then
        lines[#lines + 1] = '   ' .. result.summary
    end
    lines[#lines + 1] = ''
    return lines
end

---@param url string
local function open(url)
    if vim.fn.executable('xdg-open') == 1 then
        vim.system({ 'xdg-open', url }, { detach = true })
    else
        vim.notify(url, vim.log.levels.INFO)
    end
end

---Show search results in a scratch buffer with discovery keymaps.
---@param results table[]
---@param query string
function M.show(results, query)
    local lines = { ('arXiv results for: %s (%d)'):format(query, #results), '' }
    for i, result in ipairs(results) do
        for _, line in ipairs(result_lines(result, i)) do
            lines[#lines + 1] = line
        end
    end
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
    vim.cmd('botright split')
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_buf_set_name(bufnr, 'arXiv: ' .. query)

    ---Map a key to act on the result under the cursor.
    ---@param key string
    ---@param fn fun(result: table)
    local function map_result(key, fn)
        vim.keymap.set('n', key, function()
            local cursor = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_buf_get_lines(bufnr, cursor - 1, cursor, false)[1] or ''
            local index = tonumber(line:match('^(%d+)%.'))
            local result = index and results[index]
            if not result then
                vim.notify('No arXiv result on this line', vim.log.levels.WARN)
                return
            end
            fn(result)
        end, { buffer = bufnr, nowait = true, desc = 'arXiv result action' })
    end

    map_result('<CR>', function(result)
        open(result.pdf_url)
    end)
    map_result('y', function(result)
        vim.fn.setreg('+', result.abs_url)
        vim.fn.setreg('"', result.abs_url)
        vim.notify('Yanked ' .. result.abs_url, vim.log.levels.INFO)
    end)
    map_result('b', function(result)
        M.arxiv_to_bib({ result.id })
    end)
end

---Fetch BibTeX for arXiv IDs via arxiv2bib and show it in a scratch buffer.
---@param ids string[]
function M.arxiv_to_bib(ids)
    assert(type(ids) == 'table' and #ids > 0, 'arxiv_to_bib: ids must be a non-empty table')
    if not available('arxiv2bib') then
        vim.notify('arxiv2bib is not installed', vim.log.levels.WARN)
        return
    end
    local argv = { 'arxiv2bib', '-q' }
    for _, id in ipairs(ids) do
        argv[#argv + 1] = id
    end
    vim.system(argv, { text = true, timeout = BIB_TIMEOUT * 1000 }, function(result)
        vim.schedule(function()
            if result.code ~= 0 and (result.stdout or '') == '' then
                vim.notify(clean_text(result.stderr or 'arxiv2bib failed'), vim.log.levels.ERROR)
                return
            end
            local bufnr = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(result.stdout or '', '\n'))
            vim.api.nvim_buf_set_option(bufnr, 'filetype', 'bib')
            vim.cmd('botright split')
            vim.api.nvim_win_set_buf(0, bufnr)
            vim.api.nvim_buf_set_name(bufnr, 'BibTeX: ' .. table.concat(ids, ', '))
        end)
    end)
end

---Fetch BibTeX for one DOI via doi2bib (positional single-DOI form).
---@param doi string
function M.doi_to_bib(doi)
    assert(type(doi) == 'string' and doi ~= '', 'doi_to_bib: doi must be a non-empty string')
    if not available('doi2bib') then
        vim.notify('doi2bib is not installed', vim.log.levels.WARN)
        return
    end
    vim.system(
        { 'doi2bib', doi },
        { text = true, timeout = BIB_TIMEOUT * 1000 },
        function(result)
            vim.schedule(function()
                if result.code ~= 0 and (result.stdout or '') == '' then
                    vim.notify(clean_text(result.stderr or 'doi2bib failed'), vim.log.levels.ERROR)
                    return
                end
                local bufnr = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(result.stdout or '', '\n'))
                vim.api.nvim_buf_set_option(bufnr, 'filetype', 'bib')
                vim.cmd('botright split')
                vim.api.nvim_win_set_buf(0, bufnr)
                vim.api.nvim_buf_set_name(bufnr, 'BibTeX: ' .. doi)
            end)
        end
    )
end

---Bundle the current file's LaTeX project for arXiv submission.
---@param dest string output tarball name
function M.collect(dest)
    assert(type(dest) == 'string' and dest ~= '', 'collect: dest must be a non-empty string')
    if not available('arxiv-collector') then
        vim.notify('arxiv-collector is not installed', vim.log.levels.WARN)
        return
    end
    local dir = vim.fn.expand('%:p:h')
    vim.system(
        { 'arxiv-collector', '--dest', dest },
        { text = true, timeout = BUILD_TIMEOUT * 1000, cwd = dir },
        function(result)
            vim.schedule(function()
                if result.code == 0 then
                    vim.notify('arxiv-collector wrote ' .. dest, vim.log.levels.INFO)
                else
                    vim.notify(clean_text(result.stderr or 'arxiv-collector failed'), vim.log.levels.ERROR)
                end
            end)
        end
    )
end

---Clean a LaTeX project folder for arXiv submission.
---@param folder string input folder
---@param extra string[] extra verified flags to pass through
function M.clean(folder, extra)
    assert(type(folder) == 'string' and folder ~= '', 'clean: folder must be a non-empty string')
    if not available('arxiv_latex_cleaner') then
        vim.notify('arxiv_latex_cleaner is not installed', vim.log.levels.WARN)
        return
    end
    local argv = { 'arxiv_latex_cleaner', folder }
    for _, flag in ipairs(extra or {}) do
        argv[#argv + 1] = flag
    end
    vim.system(argv, { text = true, timeout = BUILD_TIMEOUT * 1000 }, function(result)
        vim.schedule(function()
            if result.code == 0 then
                vim.notify('arxiv_latex_cleaner finished', vim.log.levels.INFO)
            else
                vim.notify(clean_text(result.stderr or 'arxiv_latex_cleaner failed'), vim.log.levels.ERROR)
            end
        end)
    end)
end

---One-line availability report for every known tool.
---@return string[]
function M.tools_status()
    local lines = { 'arXiv CLI tools', '' }
    for _, tool in ipairs(TOOLS) do
        local state
        if tool.broken then
            state = 'BROKEN'
        elseif available(tool.name) then
            state = 'available'
        else
            state = 'not installed'
        end
        lines[#lines + 1] = ('- %s: %s — %s'):format(tool.name, state, tool.purpose)
        lines[#lines + 1] = ('  usage: %s'):format(tool.flag_note)
    end
    return lines
end

function M.setup()
    vim.api.nvim_create_user_command('ArxivFind', function(opts)
        local query = opts.args ~= '' and opts.args or nil
        if not query then
            query = vim.fn.input('arXiv query: ')
        end
        if query == '' then
            return
        end
        M.search(query, {}, function(results, err)
            if err then
                vim.notify('ArxivFind: ' .. err, vim.log.levels.ERROR)
                return
            end
            if #results == 0 then
                vim.notify('ArxivFind: no results', vim.log.levels.WARN)
                return
            end
            M.show(results, query)
        end)
    end, { nargs = '*', desc = 'Search arXiv and browse results in Neovim' })

    vim.api.nvim_create_user_command('ArxivTools', function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, M.tools_status())
        vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
        vim.cmd('botright split')
        vim.api.nvim_win_set_buf(0, bufnr)
        vim.api.nvim_buf_set_name(bufnr, 'arXiv CLI tools')
    end, { desc = 'Show arXiv CLI tool availability' })

    vim.api.nvim_create_user_command('ArxivBib', function(opts)
        local ids = {}
        for id in opts.args:gmatch('%S+') do
            ids[#ids + 1] = id
        end
        if #ids == 0 then
            vim.notify('Usage: ArxivBib {id} [{id} ...]', vim.log.levels.ERROR)
            return
        end
        M.arxiv_to_bib(ids)
    end, { nargs = '+', desc = 'Fetch BibTeX for arXiv IDs via arxiv2bib' })

    vim.api.nvim_create_user_command('DoiBib', function(opts)
        local doi = opts.args ~= '' and opts.args or nil
        if not doi then
            local ok, citation = pcall(require, 'research.citation')
            if ok then
                doi = citation.doi(vim.api.nvim_get_current_line())
            end
        end
        if not doi or doi == '' then
            vim.notify('Usage: DoiBib {doi}', vim.log.levels.ERROR)
            return
        end
        M.doi_to_bib(doi)
    end, { nargs = '*', desc = 'Fetch BibTeX for a DOI via doi2bib' })

    vim.api.nvim_create_user_command('ArxivCollect', function(opts)
        local dest = opts.args ~= '' and opts.args or 'arxiv.tar.gz'
        M.collect(dest)
    end, {
        nargs = '?',
        desc = 'Bundle the LaTeX project for arXiv submission',
    })

    vim.api.nvim_create_user_command('ArxivClean', function(opts)
        local args = {}
        for word in opts.args:gmatch('%S+') do
            args[#args + 1] = word
        end
        local folder = args[1] or vim.fn.expand('%:p:h')
        local extra = {}
        for i = 2, #args do
            extra[#extra + 1] = args[i]
        end
        M.clean(folder, extra)
    end, { nargs = '*', desc = 'Clean LaTeX sources with arxiv_latex_cleaner' })
end

return M
