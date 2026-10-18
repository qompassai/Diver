-- /qompassai/Diver/lua/research/zotero_api.lua
-- Qompass AI Diver Research Zotero Live Library API
---@module 'research.zotero_api'
--
-- Talks to the Zotero desktop app's local API so arXiv discovery can
-- check candidates against the real library and file new papers in.
--
-- Plain-language version: when you search arXiv from Neovim, this
-- module asks your own Zotero (running on this machine) which of the
-- papers you already have, and marks them in the results. Pressing f
-- on a result files that paper into Zotero with its full metadata and
-- a BibTeX record. It only ever adds: no code path in this module can
-- change or delete something already in your library.
--
-- How it connects: the Zotero local API listens on
-- http://localhost:23119/api and answers for the local user "0".
-- Write calls need the API key and server id from the local-API grant
-- stored for the Zotero MCP server (~/.config/zotero-mcp/config.json,
-- granted 2026-09-29); if that file is missing, the key falls back to
-- `pass zotero/key`. Key values are never logged, notified, returned,
-- or written anywhere by this module. When Zotero is not running or
-- no key resolves, every call degrades to (nil, err) and discovery
-- carries on unmarked instead of failing.
local M = {}

---Base URL of the Zotero desktop local API.
local API_BASE = 'http://localhost:23119/api'
---The local API always serves the desktop user under id "0".
local API_USER = '0'
---Zotero API version header sent with every request.
local API_VERSION = '3'
---Grant file written when the Zotero local API was authorized.
local CONFIG_PATH = vim.fn.expand('~/.config/zotero-mcp/config.json')
---Seconds before one HTTP request is abandoned.
local HTTP_TIMEOUT_SECONDS = 20
---Items requested per index page (the API's own maximum page size).
local INDEX_PAGE_SIZE = 100
---Hard bound on index pages per fetch (100 * 50 = 5,000 items).
local INDEX_PAGES_MAX = 50
---pass entry holding the Zotero API key (fallback source).
local PASS_ENTRY = 'zotero/key'
---Milliseconds before a `pass show` attempt is abandoned.
local PASS_TIMEOUT_MS = 5000

---@class research.ZoteroCreds
---@field key string Zotero API key (never logged or returned)
---@field server_id string? Zotero-Server-ID header value, if known

---@class research.ZoteroIndex
---@field arxiv table<string, string> base arXiv id -> item key
---@field doi table<string, string> lowercase DOI -> item key
---@field title table<string, string> normalized title -> item key

---@class research.ZoteroFiled
---@field filed boolean true when a new item was created
---@field key string item key (the new item, or the pre-existing one)
---@field note_error string? BibTeX note failure when the item filed but the note did not

---@alias research.ZoteroDone fun(status: integer?, payload: table|string?, err: string?)
---@alias research.ZoteroTransport fun(method: string, path: string, body: table?, on_done: research.ZoteroDone)

---Credentials resolved once per session (they cannot change live).
---@type research.ZoteroCreds?
local cached_creds = nil

---Trim whitespace at both ends.
---@param text string
---@return string
local function clean_text(text)
    return (text:gsub('^%s*(.-)%s*$', '%1'))
end

---Resolve the local-API credentials. The grant config is the primary
---source because it holds the key/server-id pair the write path
---needs; `pass` is the fallback for the key alone.
---@param on_done fun(creds: research.ZoteroCreds?, err: string?)
local function resolve_credentials(on_done)
    if cached_creds then
        on_done(cached_creds, nil)
        return
    end
    local server_id = nil
    local ok, lines = pcall(vim.fn.readfile, CONFIG_PATH)
    if ok and lines then
        local decoded_ok, config = pcall(vim.json.decode, table.concat(lines, '\n'))
        if decoded_ok and type(config) == 'table' and type(config.local_api) == 'table' then
            local grant = config.local_api
            if type(grant.server_id) == 'string' and grant.server_id ~= '' then
                server_id = grant.server_id
            end
            if type(grant.key) == 'string' and grant.key ~= '' then
                cached_creds = { key = grant.key, server_id = server_id }
                on_done(cached_creds, nil)
                return
            end
        end
    end
    vim.system({ 'pass', 'show', PASS_ENTRY }, { text = true, timeout = PASS_TIMEOUT_MS }, function(result)
        vim.schedule(function()
            local first_line = clean_text((result.stdout or ''):match('^[^\n]*') or '')
            if result.code == 0 and first_line ~= '' then
                cached_creds = { key = first_line, server_id = server_id }
                on_done(cached_creds, nil)
                return
            end
            on_done(nil, 'no Zotero API key available (grant config unreadable, pass locked or empty)')
        end)
    end)
end

---Default transport: one bounded curl call to the local API. The
---callback always fires on the main loop with (status, payload, err);
---payload is the decoded JSON body when the body parses as JSON.
---@type research.ZoteroTransport
local function default_transport(method, path, body, on_done)
    resolve_credentials(function(creds, cred_err)
        if not creds then
            on_done(nil, nil, cred_err)
            return
        end
        local argv = {
            'curl',
            '-sS',
            '--max-time',
            tostring(HTTP_TIMEOUT_SECONDS),
            '-X',
            method,
            '-H',
            'Zotero-API-Key: ' .. creds.key,
            '-H',
            'Zotero-API-Version: ' .. API_VERSION,
            '-H',
            'Content-Type: application/json',
            '-w',
            '\n%{http_code}',
            API_BASE .. path,
        }
        if creds.server_id then
            argv[#argv + 1] = '-H'
            argv[#argv + 1] = 'Zotero-Server-ID: ' .. creds.server_id
        end
        local stdin = nil
        if body ~= nil then
            argv[#argv + 1] = '--data-binary'
            argv[#argv + 1] = '@-'
            stdin = vim.json.encode(body)
        end
        vim.system(argv, { text = true, stdin = stdin }, function(result)
            vim.schedule(function()
                local raw = result.stdout or ''
                local payload_text, status_text = raw:match('^(.*)\n(%d%d%d)%s*$')
                if not status_text then
                    on_done(nil, nil, 'Zotero unreachable: ' .. clean_text(result.stderr or 'no response'))
                    return
                end
                local decoded_ok, payload = pcall(vim.json.decode, payload_text)
                on_done(tonumber(status_text), decoded_ok and payload or payload_text, nil)
            end)
        end)
    end)
end

---The transport every operation goes through (stubbed by tests).
---@type research.ZoteroTransport
local active_transport = default_transport

---Test seam: replace the transport, or pass nil to restore the
---default curl transport. Production code never calls this.
---@param fn research.ZoteroTransport?
function M._set_transport(fn)
    active_transport = fn or default_transport
end

---Normalize a title for equality checks: lowercase, every run of
---non-alphanumeric characters becomes one space, ends trimmed.
---@param title string
---@return string
function M.normalize_title(title)
    assert(type(title) == 'string', 'normalize_title: title must be a string')
    local lowered = title:lower()
    local spaced = lowered:gsub('[^%w]+', ' ')
    return clean_text(spaced)
end

---Strip the version suffix from an arXiv id ('2401.12345v2' ->
---'2401.12345'). Ids without a version suffix pass through unchanged.
---@param id string
---@return string
function M.base_arxiv_id(id)
    assert(type(id) == 'string', 'base_arxiv_id: id must be a string')
    return (id:gsub('v%d+$', ''))
end

---Build the match index from raw API item tables. Attachments and
---notes never identify a paper and are skipped, as are items whose
---data table is missing or malformed.
---@param items table[]
---@return research.ZoteroIndex
function M.index_from_items(items)
    assert(type(items) == 'table', 'index_from_items: items must be a table')
    local index = { arxiv = {}, doi = {}, title = {} }
    for _, item in ipairs(items) do
        local data = type(item) == 'table' and item.data or nil
        local key = type(item) == 'table' and item.key or nil
        if type(data) == 'table' and type(key) == 'string' then
            local item_type = data.itemType
            if item_type ~= 'attachment' and item_type ~= 'note' then
                if type(data.archiveID) == 'string' and data.archiveID ~= '' then
                    index.arxiv[M.base_arxiv_id(data.archiveID)] = key
                end
                if type(data.extra) == 'string' then
                    local extra_id = data.extra:match('[aA]rXiv:%s*(%S+)')
                    if extra_id then
                        index.arxiv[M.base_arxiv_id(extra_id)] = key
                    end
                end
                if type(data.url) == 'string' then
                    local url_id = data.url:match('arxiv%.org/abs/(%S+)$')
                    if url_id then
                        index.arxiv[M.base_arxiv_id(url_id)] = key
                    end
                end
                if type(data.DOI) == 'string' and data.DOI ~= '' then
                    index.doi[data.DOI:lower()] = key
                end
                if type(data.title) == 'string' and data.title ~= '' then
                    index.title[M.normalize_title(data.title)] = key
                end
            end
        end
    end
    return index
end

---Find the library item key for one discovery candidate, or nil.
---Signals are tried in strength order: arXiv id, DOI, normalized
---title. Title is the weakest signal — two papers can share one —
---but it is the only signal when the library copy was filed from a
---publisher page and carries no arXiv id.
---@param result table discovery candidate (research.discover shape)
---@param index research.ZoteroIndex
---@return string?
function M.match_candidate(result, index)
    assert(type(result) == 'table', 'match_candidate: result must be a table')
    assert(type(index) == 'table', 'match_candidate: index must be a table')
    if type(result.id) == 'string' and result.id ~= '' then
        local by_id = index.arxiv[M.base_arxiv_id(result.id)]
        if by_id then
            return by_id
        end
    end
    if type(result.doi) == 'string' and result.doi ~= '' then
        local by_doi = index.doi[result.doi:lower()]
        if by_doi then
            return by_doi
        end
    end
    if type(result.title) == 'string' and result.title ~= '' then
        return index.title[M.normalize_title(result.title)]
    end
    return nil
end

---Fetch the whole library index, page by page. The callback receives
---(index, item_count) or (nil, err). Work is bounded by
---INDEX_PAGES_MAX pages of INDEX_PAGE_SIZE items.
---@param on_done fun(index: research.ZoteroIndex?, count_or_err: integer|string)
function M.fetch_index(on_done)
    assert(type(on_done) == 'function', 'fetch_index: on_done must be a function')
    local items = {}
    local function fetch_page(page)
        local start = page * INDEX_PAGE_SIZE
        local path = ('/users/%s/items?limit=%d&start=%d&itemType=-attachment'):format(API_USER, INDEX_PAGE_SIZE, start)
        active_transport('GET', path, nil, function(status, payload, err)
            if err then
                on_done(nil, err)
                return
            end
            if status ~= 200 or type(payload) ~= 'table' then
                on_done(nil, ('Zotero library request failed (HTTP %s)'):format(tostring(status)))
                return
            end
            for _, item in ipairs(payload) do
                items[#items + 1] = item
            end
            if #payload < INDEX_PAGE_SIZE or page + 1 >= INDEX_PAGES_MAX then
                on_done(M.index_from_items(items), #items)
                return
            end
            fetch_page(page + 1)
        end)
    end
    fetch_page(0)
end

---Annotate discovery candidates in place: result.in_library (boolean)
---and result.zotero_key (string) when already filed. The callback
---receives (results) on success or (nil, err) when the library
---cannot be read; candidates are untouched in the error case so the
---caller can show them unmarked with a warning.
---@param results table[]
---@param on_done fun(results: table[]?, err: string?)
function M.mark_candidates(results, on_done)
    assert(type(results) == 'table', 'mark_candidates: results must be a table')
    assert(type(on_done) == 'function', 'mark_candidates: on_done must be a function')
    M.fetch_index(function(index, count_or_err)
        if not index then
            on_done(nil, tostring(count_or_err))
            return
        end
        for _, result in ipairs(results) do
            local key = M.match_candidate(result, index)
            result.in_library = key ~= nil
            result.zotero_key = key
        end
        on_done(results, nil)
    end)
end

---Build the Zotero item table for one candidate (pure; no I/O).
---Returns the item, or (nil, err) when the candidate is malformed.
---@param result table discovery candidate (research.discover shape)
---@return table? item
---@return string? err
function M.build_item(result)
    if type(result) ~= 'table' then
        return nil, 'candidate must be a table'
    end
    if type(result.title) ~= 'string' or result.title == '' then
        return nil, 'candidate has no title'
    end
    if type(result.id) ~= 'string' or result.id == '' then
        return nil, 'candidate has no arXiv id'
    end
    if result.authors ~= nil and type(result.authors) ~= 'table' then
        return nil, 'candidate authors must be a table'
    end
    local creators = {}
    for _, name in ipairs(result.authors or {}) do
        if type(name) == 'string' and name ~= '' then
            local first, last = name:match('^(.-)%s+([^%s]+)$')
            if first then
                creators[#creators + 1] = { creatorType = 'author', firstName = first, lastName = last }
            else
                creators[#creators + 1] = { creatorType = 'author', lastName = name }
            end
        end
    end
    local base_id = M.base_arxiv_id(result.id)
    local item = {
        abstractNote = type(result.summary) == 'string' and result.summary or '',
        archiveID = base_id,
        creators = creators,
        extra = 'arXiv: ' .. base_id,
        itemType = 'preprint',
        repository = 'arXiv',
        title = result.title,
        url = 'https://arxiv.org/abs/' .. base_id,
    }
    if type(result.published) == 'string' and result.published:match('^%d%d%d%d') then
        item.date = result.published:sub(1, 10)
    end
    if type(result.doi) == 'string' and result.doi ~= '' then
        item.DOI = result.doi
    end
    return item, nil
end

---BibTeX citation key for a candidate: first author's last name,
---year, and the first title word, lowercased alphanumerics only.
---@param result table discovery candidate (research.discover shape)
---@return string
function M.bibtex_key(result)
    assert(type(result) == 'table', 'bibtex_key: result must be a table')
    local last = 'unknown'
    local authors = type(result.authors) == 'table' and result.authors or {}
    if type(authors[1]) == 'string' and authors[1] ~= '' then
        last = authors[1]:match('([^%s]+)%s*$') or 'unknown'
    end
    local year = 'nd'
    if type(result.published) == 'string' and result.published:match('^%d%d%d%d') then
        year = result.published:sub(1, 4)
    end
    local word = 'paper'
    if type(result.title) == 'string' then
        word = result.title:match('%w+') or 'paper'
    end
    local raw = (last .. year .. word):lower()
    return (raw:gsub('[^%w]', ''))
end

---Remove braces from a BibTeX field value (they would break parsing).
---@param value string
---@return string
local function bib_field(value)
    return (value:gsub('[{}]', ''))
end

---BibTeX record for one candidate (pure; no I/O). Mirrors the
---@param result table discovery candidate (research.discover shape)
---@return string
function M.bibtex_for(result)
    assert(type(result) == 'table', 'bibtex_for: result must be a table')
    local base_id = type(result.id) == 'string' and M.base_arxiv_id(result.id) or ''
    local author_names = {}
    for _, name in ipairs(type(result.authors) == 'table' and result.authors or {}) do
        if type(name) == 'string' and name ~= '' then
            author_names[#author_names + 1] = bib_field(name)
        end
    end
    local lines = { ('@misc{%s,'):format(M.bibtex_key(result)) }
    lines[#lines + 1] = ('    title = {%s},'):format(bib_field(result.title or ''))
    if #author_names > 0 then
        lines[#lines + 1] = ('    author = {%s},'):format(table.concat(author_names, ' and '))
    end
    if type(result.published) == 'string' and result.published:match('^%d%d%d%d') then
        lines[#lines + 1] = ('    year = {%s},'):format(result.published:sub(1, 4))
    end
    if base_id ~= '' then
        lines[#lines + 1] = ('    eprint = {%s},'):format(base_id)
        lines[#lines + 1] = '    archivePrefix = {arXiv},'
        lines[#lines + 1] = ('    url = {https://arxiv.org/abs/%s},'):format(base_id)
    end
    if type(result.doi) == 'string' and result.doi ~= '' then
        lines[#lines + 1] = ('    doi = {%s},'):format(bib_field(result.doi))
    end
    lines[#lines] = lines[#lines]:gsub(',$', '')
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n')
end

---Escape text for inclusion in a Zotero note (notes store HTML).
---@param text string
---@return string
local function html_escape(text)
    local escaped = text:gsub('&', '&amp;')
    escaped = escaped:gsub('<', '&lt;')
    escaped = escaped:gsub('>', '&gt;')
    return escaped
end

---File one candidate into Zotero: create the item, then attach its
---BibTeX record as a child note. This module only ever creates; an
---already-filed candidate is reported, never duplicated. The
---callback receives a table { key, filed, note_error? } or
---(nil, err). filed is false when the paper was already present.
---@param result table discovery candidate (research.discover shape)
---@param on_done fun(filed: research.ZoteroFiled?, err: string?)
function M.file_candidate(result, on_done)
    assert(type(on_done) == 'function', 'file_candidate: on_done must be a function')
    local item, build_err = M.build_item(result)
    if not item then
        on_done(nil, build_err)
        return
    end
    M.fetch_index(function(index, count_or_err)
        if not index then
            on_done(nil, 'cannot check library before filing: ' .. tostring(count_or_err))
            return
        end
        local existing = M.match_candidate(result, index)
        if existing then
            on_done({ filed = false, key = existing }, nil)
            return
        end
        active_transport('POST', '/users/' .. API_USER .. '/items', { item }, function(status, payload, err)
            if err then
                on_done(nil, err)
                return
            end
            local created = type(payload) == 'table' and payload.successful and payload.successful['0'] or nil
            if status ~= 200 and status ~= 201 or type(created) ~= 'table' or type(created.key) ~= 'string' then
                on_done(nil, ('Zotero filing failed (HTTP %s)'):format(tostring(status)))
                return
            end
            local item_key = created.key
            local note = {
                itemType = 'note',
                note = '<pre>' .. html_escape(M.bibtex_for(result)) .. '</pre>',
                parentItem = item_key,
                tags = {},
            }
            active_transport('POST', '/users/' .. API_USER .. '/items', { note }, function(note_status, _, note_err)
                if note_err or (note_status ~= 200 and note_status ~= 201) then
                    on_done({
                        filed = true,
                        key = item_key,
                        note_error = note_err or ('HTTP ' .. tostring(note_status)),
                    }, nil)
                    return
                end
                on_done({ filed = true, key = item_key }, nil)
            end)
        end)
    end)
end

---One-line library status for :ZoteroLibraryStatus.
---@param on_done fun(line: string)
function M.status(on_done)
    assert(type(on_done) == 'function', 'status: on_done must be a function')
    M.fetch_index(function(index, count_or_err)
        if not index then
            on_done('Zotero library unavailable: ' .. tostring(count_or_err))
            return
        end
        on_done(('Zotero library reachable: %d items indexed'):format(tonumber(count_or_err) or 0))
    end)
end

function M.setup()
    vim.api.nvim_create_user_command('ZoteroLibraryStatus', function()
        M.status(function(line)
            vim.notify(line, vim.log.levels.INFO)
        end)
    end, { desc = 'Check the live Zotero library connection' })
end

return M
