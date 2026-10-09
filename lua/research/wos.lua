-- /qompassai/Diver/lua/research/wos.lua
-- Qompass AI Diver Web of Science Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Web of Science lookups from inside Neovim (Starter API,
-- https://developer.clarivate.com/apis/wos-starter): resolve a DOI or
-- a WoS accession number (UID) to a normalized record, read a work's
-- times-cited count, and attach citation counts to the works on your
-- ORCID record (research.orcid).
--
-- Deliberate boundaries:
-- - Read-only. The Starter API is GET-only; this module never writes
--   to Web of Science. Profile curation and the ORCID sync happen on
--   the WoS website, not through this API.
-- - The API key resolves in this order: WOS_API_KEY environment
--   override, then the sops+age automation tier via the
--   research-secret accessor (field wos_api_key; tier README at
--   ~/.local/share/diver/secrets/README.md), then a setup() key
--   (last-resort programmatic override for tests, never persisted
--   anywhere). pass is deliberately NOT in this chain: `pass ls`
--   (checked 2026-10-08) holds no Web of Science or Clarivate entry.
--   A tier value of REPLACE_ME counts as not-yet-populated. Every
--   failure degrades to a structured error table
--   { code = ..., message = ... } — no crash, no retry loop, and no
--   fallback ever writes the key to disk or a buffer.
-- - Times cited is plan-dependent: the free trial plan omits citation
--   counts (the record simply has no citations array), so
--   times_cited reports 'times_cited_unavailable' instead of a wrong
--   zero. The free institutional-member plan returns real counts.
local api = vim.api
local fn = vim.fn
local M = {}

local API_BASE_URL = 'https://api.clarivate.com/apis/wos-starter/v1'
local DATABASE = 'WOS'
local DISPLAY_LINES_MAX = 200
local PLACEHOLDER_SECRET = 'REPLACE_ME'
local REQUEST_TIMEOUT_SEC = 30
local RESEARCH_SECRET_BIN = fn.expand('~/.local/bin/research-secret')
local SECRET_FIELD_API_KEY = 'wos_api_key'
local SECRET_TIMEOUT_MS = 5000
local STATUS_MARKER = '__WOS_HTTP_STATUS__:'
local WORKS_BATCH_MAX = 50

---@class WosConfig
---@field api_base string
---@field api_key string|nil setup-only key (never persisted)
---@field secret_field string research-secret field for the key ('' disables the tier)
---@field transport function|nil setup-only HTTP seam for tests: fn(url, key) -> status, body
---@field works_provider function|nil setup-only seam for tests: fn() -> works, err

---@class WosError
---@field code string machine-readable error code
---@field message string human-readable detail
---@field sources_tried? string[] secret sources consulted (secret errors only)
---@field status? integer HTTP status (http/auth errors only)

---@class WosRecord
---@field authors string[]
---@field doi string|nil
---@field issue string|nil
---@field pages string|nil
---@field source string|nil
---@field times_cited integer|nil nil when the plan/record carries no count
---@field title string
---@field uid string
---@field url string|nil
---@field volume string|nil
---@field year integer|nil

---@class WosWorkCitations
---@field doi string|nil
---@field error string|nil per-work failure note (the batch survives it)
---@field journal string|nil
---@field times_cited integer|nil
---@field title string
---@field year string|nil

---@type WosConfig
local config = {
    api_base = API_BASE_URL,
    api_key = nil,
    secret_field = SECRET_FIELD_API_KEY,
    transport = nil,
    works_provider = nil,
}

---@param code string
---@param message string
---@return WosError
local function make_error(code, message)
    return { code = code, message = message }
end

---Read a secret from the sops+age automation tier via the
---research-secret accessor (absolute path: a non-interactive PATH lacks
---~/.local/bin; the tier is documented in
---~/.local/share/diver/secrets/README.md). Output is never logged. The
---placeholder value counts as not-yet-populated. Any failure — accessor
---missing, key refused, field absent — returns nil with `unavailable`
---true: a structured degradation, never an error.
---@param field string
---@return string|nil secret
---@return boolean unavailable true when the tier could not provide it
local function get_research_secret(field)
    assert(type(field) == 'string', 'field must be a string')
    if fn.executable(RESEARCH_SECRET_BIN) ~= 1 then
        return nil, true
    end
    local ok, result = pcall(vim.system, { RESEARCH_SECRET_BIN, field }, { text = true, timeout = SECRET_TIMEOUT_MS })
    if not ok then
        return nil, true
    end
    local finished = result:wait(SECRET_TIMEOUT_MS)
    if finished.code ~= 0 then
        return nil, true
    end
    local secret = vim.trim(finished.stdout or '')
    if secret == '' or secret == PLACEHOLDER_SECRET then
        return nil, true
    end
    return secret, false
end

---Resolve the API key: WOS_API_KEY environment override first, then
---the sops+age tier (research-secret), then a setup() key (test seam).
---@return string|nil api_key
---@return WosError|nil err structured error carrying sources_tried
local function get_api_key()
    local from_env = os.getenv('WOS_API_KEY')
    if from_env and from_env ~= '' then
        return from_env, nil
    end
    local sources_tried = { 'env' }
    local tier_consulted = false
    if config.secret_field and config.secret_field ~= '' then
        tier_consulted = true
        sources_tried[#sources_tried + 1] = 'tier'
        local from_tier = get_research_secret(config.secret_field)
        if from_tier then
            return from_tier, nil
        end
    end
    if config.api_key and config.api_key ~= '' then
        return config.api_key, nil
    end
    local err
    if tier_consulted then
        err = make_error(
            'secret_unavailable',
            'Web of Science API key unavailable: WOS_API_KEY is unset and no key '
                .. 'could be read from the research-secret tier field '
                .. config.secret_field
                .. ' (secret unavailable — tier not yet populated?)'
        )
    else
        err = make_error(
            'not_configured',
            'Web of Science API key not configured: set the WOS_API_KEY environment '
                .. 'variable or populate the research-secret tier (field '
                .. SECRET_FIELD_API_KEY
                .. ') (never in a config file)'
        )
    end
    err.sources_tried = sources_tried
    return nil, err
end

---Report an error without throwing. An ERROR-level notification
---emitted during command execution makes nvim_exec2 fail the command
---for API/RPC callers (stock vim.notify echoes with err=true), so the
---notification is scheduled: the command returns cleanly and the
---message still displays.
---@param message string
local function notify_error(message)
    vim.schedule(function()
        vim.notify(message, vim.log.levels.ERROR)
    end)
end

---URL-encode a query value. Only unreserved characters pass through.
---@param value string
---@return string
local function url_encode(value)
    return (value:gsub('[^%w%-%._~]', function(char)
        return ('%%%02X'):format(char:byte())
    end))
end

---Default HTTP transport: one bounded, synchronous HTTPS GET via curl.
---Returns the HTTP status and the raw body for any completed response
---(including error statuses, so callers can classify them), or nil
---plus a structured error when the request never completed.
---@param url string full URL
---@param api_key string
---@return integer|nil status
---@return string|WosError body raw response text, or an error table
local function default_transport(url, api_key)
    local cmd = {
        'curl',
        '--silent',
        '--show-error',
        '--max-time',
        tostring(REQUEST_TIMEOUT_SEC),
        '--header',
        'X-ApiKey: ' .. api_key,
        '--header',
        'Accept: application/json',
        '--write-out',
        '\n' .. STATUS_MARKER .. '%{http_code}',
        url,
    }
    local result = vim.system(cmd, { text = true }):wait(REQUEST_TIMEOUT_SEC * 1000 + 5000)
    local stdout = result.stdout or ''
    local body, status_text = stdout:match('^(.*)\n' .. STATUS_MARKER .. '(%d+)%s*$')
    if result.code ~= 0 or body == nil then
        local detail = vim.trim(result.stderr or '')
        if detail == '' then
            detail = 'HTTP request failed'
        end
        return nil, make_error('http', ('Web of Science request failed: %s'):format(detail))
    end
    return tonumber(status_text), body
end

---One API request, classified. 401 is its own code (the Starter API
---answers it with an OAuth-style body, unlike every other error);
---other non-200 statuses carry the API's { error = { title,
---details } } body when it parses. A 200 with an unparseable body is
---'invalid_response', never a silent empty table.
---@param url string full URL
---@param api_key string
---@return table|nil decoded decoded JSON body
---@return WosError|nil err
local function request_json(url, api_key)
    local transport = config.transport or default_transport
    local status, body = transport(url, api_key)
    if status == nil then
        ---@cast body WosError
        return nil, body
    end
    ---@cast body string
    if status == 401 then
        local detail = 'the API key is missing or invalid'
        local ok, decoded = pcall(vim.json.decode, body)
        if ok and type(decoded) == 'table' and type(decoded.error_description) == 'string' then
            detail = decoded.error_description
        end
        local err = make_error('auth', ('Web of Science API key rejected (HTTP 401): %s'):format(detail))
        err.status = 401
        return nil, err
    end
    if status ~= 200 then
        local detail = ('HTTP %d'):format(status)
        local ok, decoded = pcall(vim.json.decode, body)
        if ok and type(decoded) == 'table' and type(decoded.error) == 'table' then
            local title = type(decoded.error.title) == 'string' and decoded.error.title or 'error'
            local details = type(decoded.error.details) == 'string' and decoded.error.details or ''
            detail = ('%s — %s: %s'):format(detail, title, details)
        end
        local err = make_error('http', ('Web of Science request failed: %s'):format(detail))
        err.status = status
        return nil, err
    end
    local ok, decoded = pcall(vim.json.decode, body)
    if not ok or type(decoded) ~= 'table' then
        return nil, make_error('invalid_response', 'Web of Science response was not valid JSON')
    end
    return decoded, nil
end

---A UID (accession number) looks like WOS:000282418500002 — a
---collection prefix, a colon, then the accession characters.
---@param value string
---@return boolean
local function is_uid(value)
    return value:match('^[A-Z][A-Z0-9]*:[%w%.%-]+$') ~= nil
end

---Normalize a DOI as a user might type it: trim, drop a doi.org URL
---or 'doi:' prefix, then require the registrant form (10.<code>/…).
---Returns nil when the value cannot be a DOI.
---@param raw string
---@return string|nil doi
local function normalize_doi(raw)
    local value = vim.trim(raw)
    local lowered = value:lower()
    for _, prefix in ipairs({ 'https://doi.org/', 'http://doi.org/', 'doi:' }) do
        if lowered:sub(1, #prefix) == prefix then
            value = value:sub(#prefix + 1)
            break
        end
    end
    value = vim.trim(value)
    if value:match('^10%.[%d%.]+/%S+$') == nil then
        return nil
    end
    return value
end

---Normalize one raw Starter API document into a WosRecord. Every
---field is type-guarded: JSON null decodes to vim.NIL (truthy), and
---plan-dependent fields (citations, links) may be absent entirely.
---@param hit table raw document from the API
---@return WosRecord
local function normalize_hit(hit)
    local record = { authors = {}, title = '(untitled)', uid = '' }
    if type(hit.uid) == 'string' then
        record.uid = hit.uid
    end
    if type(hit.title) == 'string' then
        record.title = hit.title
    end
    local source = hit.source
    if type(source) == 'table' then
        if type(source.sourceTitle) == 'string' then
            record.source = source.sourceTitle
        end
        if type(source.publishYear) == 'number' then
            record.year = source.publishYear
        end
        if type(source.volume) == 'string' then
            record.volume = source.volume
        end
        if type(source.issue) == 'string' then
            record.issue = source.issue
        end
        local pages = source.pages
        if type(pages) == 'table' then
            if type(pages.range) == 'string' then
                record.pages = pages.range
            elseif type(pages.begin) == 'string' and type(pages['end']) == 'string' then
                record.pages = pages.begin .. '-' .. pages['end']
            end
        end
    end
    local names = hit.names
    if type(names) == 'table' and type(names.authors) == 'table' then
        for _, author in ipairs(names.authors) do
            if type(author) == 'table' then
                local name = author.displayName or author.wosStandard
                if type(name) == 'string' then
                    record.authors[#record.authors + 1] = name
                end
            end
        end
    end
    local identifiers = hit.identifiers
    if type(identifiers) == 'table' and type(identifiers.doi) == 'string' then
        record.doi = identifiers.doi
    end
    local links = hit.links
    if type(links) == 'table' and type(links.record) == 'string' then
        record.url = links.record
    end
    if type(hit.citations) == 'table' then
        for _, citation in ipairs(hit.citations) do
            if type(citation) == 'table' and citation.db == DATABASE and type(citation.count) == 'number' then
                record.times_cited = citation.count
                break
            end
        end
    end
    return record
end

---Classify a 404 from either lookup route as 'not_found' (the API
---uses it both for unknown UIDs and for searches with no record).
---@param err WosError
---@return WosError
local function as_not_found(err)
    if err.status == 404 then
        err.code = 'not_found'
    end
    return err
end

---Look up one document with an already-resolved key.
---@param query string DOI or UID
---@param api_key string
---@return WosRecord|nil record
---@return WosError|nil err
local function lookup_with_key(query, api_key)
    if is_uid(query) then
        local document, err = request_json(('%s/documents/%s'):format(config.api_base, query), api_key)
        if not document then
            return nil, as_not_found(err)
        end
        if type(document.uid) ~= 'string' then
            return nil, make_error('invalid_response', 'Web of Science document response carried no uid')
        end
        return normalize_hit(document), nil
    end
    local doi = normalize_doi(query)
    if doi == nil then
        return nil, make_error('invalid_argument', ('not a DOI or UID: %s'):format(query))
    end
    local encoded = url_encode(('DO=(%s)'):format(doi))
    local url = ('%s/documents?db=%s&q=%s&limit=1'):format(config.api_base, DATABASE, encoded)
    local result, err = request_json(url, api_key)
    if not result then
        return nil, as_not_found(err)
    end
    local hits = result.hits
    if type(hits) ~= 'table' or #hits == 0 then
        return nil, make_error('not_found', ('no Web of Science record for DOI %s'):format(doi))
    end
    local record = normalize_hit(hits[1])
    if record.doi == nil then
        record.doi = doi
    end
    return record, nil
end

---Resolve a DOI or WoS UID to a normalized record.
---@param doi_or_uid string DOI (10.…/…) or UID (e.g. WOS:000282418500002)
---@return WosRecord|nil record
---@return WosError|nil err
function M.lookup(doi_or_uid)
    if type(doi_or_uid) ~= 'string' or vim.trim(doi_or_uid) == '' then
        return nil, make_error('invalid_argument', 'lookup needs a DOI or a Web of Science UID (accession number)')
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    return lookup_with_key(vim.trim(doi_or_uid), api_key)
end

---Read one work's times-cited count (Core Collection) by DOI or UID.
---A record that carries no count — the trial plan omits citations —
---is 'times_cited_unavailable', never a fabricated zero.
---@param doi string DOI or UID
---@return integer|nil count
---@return WosError|nil err
function M.times_cited(doi)
    local record, err = M.lookup(doi)
    if not record then
        return nil, err
    end
    if record.times_cited == nil then
        return nil,
            make_error(
                'times_cited_unavailable',
                (
                    'Web of Science returned no citation count for %s — the free trial plan '
                    .. 'omits times cited; an institutional plan includes it'
                ):format(record.doi or record.uid)
            )
    end
    return record.times_cited, nil
end

---Works source for the citations batch: research.orcid by default
---(its get_works returns DOI-carrying works), replaceable in tests.
---@return table[]|nil works
---@return string|nil err
local function fetch_orcid_works()
    if config.works_provider ~= nil then
        return config.works_provider()
    end
    local orcid = require('research.orcid')
    return orcid.get_works(nil, WORKS_BATCH_MAX)
end

---Attach a WoS times-cited count to each of your ORCID works.
---Bounded at WORKS_BATCH_MAX works, sequential (Starter plans allow
---1–5 requests/second), and per-work failures land on the entry's
---error field — one bad DOI never sinks the batch.
---@return WosWorkCitations[]|nil entries
---@return WosError|nil err
function M.works_with_citations()
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local works, works_err = fetch_orcid_works()
    if works == nil then
        return nil, make_error('orcid_unavailable', ('could not read your ORCID works: %s'):format(tostring(works_err)))
    end
    local entries = {}
    for index, work in ipairs(works) do
        if index > WORKS_BATCH_MAX then
            break
        end
        local entry = {
            doi = work.doi,
            journal = work.journal,
            title = work.title or '(untitled)',
            year = work.year,
        }
        if work.doi == nil then
            entry.error = 'no DOI on the ORCID record'
        else
            local record, lookup_err = lookup_with_key(work.doi, api_key)
            if record == nil then
                entry.error = lookup_err.message
            elseif record.times_cited == nil then
                entry.error = 'no citation count returned (plan omits times cited?)'
            else
                entry.times_cited = record.times_cited
            end
        end
        entries[#entries + 1] = entry
    end
    return entries, nil
end

---@param title string
---@param lines string[]
local function show_lines(title, lines)
    local buf = api.nvim_create_buf(false, true)
    local bounded = {}
    for index, line in ipairs(lines) do
        if index > DISPLAY_LINES_MAX then
            bounded[#bounded + 1] = '... (truncated)'
            break
        end
        bounded[#bounded + 1] = line
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, bounded)
    vim.bo[buf].filetype = 'markdown'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.cmd('botright split')
    api.nvim_win_set_buf(0, buf)
    api.nvim_buf_set_name(buf, title)
end

---@param record WosRecord
---@return string[]
local function record_lines(record)
    local lines = {
        ('## %s'):format(record.title),
        '',
        ('- UID: %s'):format(record.uid),
        ('- Authors: %s'):format(#record.authors > 0 and table.concat(record.authors, '; ') or 'not recorded'),
        ('- Source: %s'):format(record.source or 'not recorded'),
        ('- Year: %s'):format(record.year ~= nil and tostring(record.year) or 'not recorded'),
    }
    local locator = {}
    if record.volume then
        locator[#locator + 1] = 'vol. ' .. record.volume
    end
    if record.issue then
        locator[#locator + 1] = 'no. ' .. record.issue
    end
    if record.pages then
        locator[#locator + 1] = 'pp. ' .. record.pages
    end
    lines[#lines + 1] = ('- Volume/issue/pages: %s'):format(
        #locator > 0 and table.concat(locator, ', ') or 'not recorded'
    )
    lines[#lines + 1] = ('- DOI: %s'):format(record.doi or 'not recorded')
    if record.times_cited ~= nil then
        lines[#lines + 1] = ('- Times cited (WoS Core): %d'):format(record.times_cited)
    else
        lines[#lines + 1] = '- Times cited: not returned (plan omits citation counts)'
    end
    lines[#lines + 1] = ('- Record: %s'):format(record.url or 'not recorded')
    return lines
end

---@param entries WosWorkCitations[]
---@return string[]
local function works_lines(entries)
    local lines = { '# Web of Science — citations for your ORCID works', '' }
    if #entries == 0 then
        lines[#lines + 1] = '(no works found on the ORCID record)'
    end
    for _, entry in ipairs(entries) do
        local head = ('- %s'):format(entry.title)
        if entry.year then
            head = head .. (' (%s)'):format(entry.year)
        end
        lines[#lines + 1] = head
        if entry.times_cited ~= nil then
            lines[#lines + 1] = ('  - Times cited: %d — doi:%s'):format(entry.times_cited, entry.doi or '?')
        else
            lines[#lines + 1] = ('  - Times cited: unavailable — %s'):format(entry.error or 'unknown error')
        end
    end
    return lines
end

---Show one record in a scratch buffer.
---@param query string DOI or UID
---@return nil
function M.show_lookup(query)
    local record, err = M.lookup(query)
    if not record then
        notify_error(('WoS: %s'):format(err.message))
        return
    end
    show_lines('Web of Science Record', record_lines(record))
end

---Report one work's times-cited count.
---@param doi string DOI or UID
---@return nil
function M.show_times_cited(doi)
    local count, err = M.times_cited(doi)
    if count == nil then
        notify_error(('WoS: %s'):format(err.message))
        return
    end
    vim.notify(('WoS: times cited %d'):format(count), vim.log.levels.INFO)
end

---Show citation counts for your ORCID works in a scratch buffer.
---@return nil
function M.show_works()
    local entries, err = M.works_with_citations()
    if not entries then
        notify_error(('WoS: %s'):format(err.message))
        return
    end
    show_lines('Web of Science Citations', works_lines(entries))
end

---@param opts? WosConfig partial overrides (api_base, api_key, secret_field, transport, works_provider)
---@return nil
function M.setup(opts)
    opts = opts or {}
    if opts.api_base ~= nil then
        assert(type(opts.api_base) == 'string', 'api_base must be a string')
        config.api_base = opts.api_base
    end
    if opts.api_key ~= nil then
        assert(type(opts.api_key) == 'string', 'api_key must be a string')
        config.api_key = opts.api_key
    end
    if opts.secret_field ~= nil then
        assert(type(opts.secret_field) == 'string', 'secret_field must be a string')
        config.secret_field = opts.secret_field
    end
    if opts.transport ~= nil then
        assert(type(opts.transport) == 'function', 'transport must be a function')
        config.transport = opts.transport
    end
    if opts.works_provider ~= nil then
        assert(type(opts.works_provider) == 'function', 'works_provider must be a function')
        config.works_provider = opts.works_provider
    end

    api.nvim_create_user_command('WosLookup', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('WoS: usage :WosLookup <doi-or-uid>', vim.log.levels.WARN)
            return
        end
        M.show_lookup(query)
    end, {
        nargs = '?',
        desc = 'Look up a DOI or UID in Web of Science',
    })

    api.nvim_create_user_command('WosCited', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('WoS: usage :WosCited <doi>', vim.log.levels.WARN)
            return
        end
        M.show_times_cited(query)
    end, {
        nargs = '?',
        desc = 'Show the WoS times-cited count for a DOI',
    })

    api.nvim_create_user_command('WosWorks', function()
        M.show_works()
    end, { desc = 'Show WoS citation counts for your ORCID works' })
end

return M
