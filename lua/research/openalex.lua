-- /qompassai/Diver/lua/research/openalex.lua
-- Qompass AI Diver OpenAlex Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- OpenAlex lookups from inside Neovim (https://api.openalex.org,
-- docs at https://docs.openalex.org): resolve a DOI or an OpenAlex
-- work ID to a normalized record, search works, read an author's
-- works by ORCID, snowball the citation graph (works citing a work,
-- and the works it references), and look up sources (venues) with
-- group_by counts composed into a venue ranking.
--
-- Deliberate boundaries:
-- - Read-only. The API is GET-only for consumers; this module never
--   writes to OpenAlex. There is no journal-finder endpoint: venue
--   ranking is composed here from /sources records and /works
--   group_by counts, nothing more.
-- - The API key resolves in this order: OPENALEX_API_KEY environment
--   override, then the sops+age automation tier via the
--   research-secret accessor (field openalex_api_key; tier README at
--   ~/.local/share/diver/secrets/README.md), then a setup() key
--   (last-resort programmatic override for tests, never persisted
--   anywhere). pass is deliberately NOT in this chain: `pass ls`
--   (checked 2026-10-08) holds no OpenAlex entry. A tier value of
--   REPLACE_ME counts as not-yet-populated. Every failure degrades
--   to a structured error table { code = ..., message = ... } — no
--   crash, no retry loop, and no fallback ever writes the key to
--   disk or a buffer.
-- - OpenAlex tolerates keyless casual use, but the free key raises
--   the daily budget 10x (docs: rate limits and authentication), and
--   this module follows the house secret chain: no key means
--   'secret_unavailable', never a silent anonymous fallback.
-- - Result sets are bounded everywhere. List calls follow the API's
--   cursor paging (per_page max 100 is the API's own cap) up to
--   PAGES_MAX pages and the caller's limit, and report the API's
--   total count plus a truncated flag when a cap cut the set — a
--   capped list is never presented as the complete result.
local api = vim.api
local fn = vim.fn
local M = {}

local API_BASE_URL = 'https://api.openalex.org'
local DEFAULT_ORCID = '0000-0002-0302-4812'
local DISPLAY_LINES_MAX = 200
local LIST_LIMIT_DEFAULT = 25
local LIST_LIMIT_MAX = 200
local PAGES_MAX = 5
local PER_PAGE_MAX = 100
local PLACEHOLDER_SECRET = 'REPLACE_ME'
local REFERENCES_RESOLVE_MAX = 50
local REQUEST_TIMEOUT_SEC = 30
local RESEARCH_SECRET_BIN = '/home/phaedrus/.local/bin/research-secret'
local SECRET_FIELD_API_KEY = 'openalex_api_key'
local SECRET_TIMEOUT_MS = 5000
local STATUS_MARKER = '__OPENALEX_HTTP_STATUS__:'
local VENUE_GROUPS_MAX = 50

---@class OpenAlexConfig
---@field api_base string
---@field api_key string|nil setup-only key (never persisted)
---@field secret_field string research-secret field for the key ('' disables the tier)
---@field transport function|nil setup-only HTTP seam for tests: fn(url, key) -> status, body

---@class OpenAlexError
---@field code string machine-readable error code
---@field message string human-readable detail
---@field sources_tried? string[] secret sources consulted (secret errors only)
---@field status? integer HTTP status (http/auth errors only)

---@class OpenAlexAuthor
---@field cited_by_count integer|nil
---@field id string OpenAlex author key (A…)
---@field name string
---@field orcid string|nil bare ORCID iD (no URL)
---@field url string full OpenAlex ID URL
---@field works_count integer|nil

---@class OpenAlexSource
---@field cited_by_count integer|nil
---@field h_index integer|nil
---@field homepage_url string|nil
---@field id string OpenAlex source key (S…)
---@field is_oa boolean|nil
---@field issn string[]
---@field issn_l string|nil
---@field mean_citedness_2yr number|nil
---@field name string
---@field type string|nil
---@field url string full OpenAlex ID URL
---@field works_count integer|nil

---@class OpenAlexVenueCount
---@field count integer works in the queried set published in this source
---@field source_id string OpenAlex source key (S…)
---@field source_name string

---@class OpenAlexWork
---@field authors string[]
---@field cited_by_count integer|nil
---@field doi string|nil bare DOI (no URL)
---@field id string OpenAlex work key (W…)
---@field referenced_count integer|nil
---@field source string|nil primary source (venue) display name
---@field source_id string|nil OpenAlex source key (S…)
---@field title string
---@field type string|nil
---@field url string full OpenAlex ID URL
---@field year integer|nil

---@type OpenAlexConfig
local config = {
    api_base = API_BASE_URL,
    api_key = nil,
    secret_field = SECRET_FIELD_API_KEY,
    transport = nil,
}

---@param code string
---@param message string
---@return OpenAlexError
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

---Resolve the API key: OPENALEX_API_KEY environment override first,
---then the sops+age tier (research-secret), then a setup() key (test
---seam).
---@return string|nil api_key
---@return OpenAlexError|nil err structured error carrying sources_tried
local function get_api_key()
    local from_env = os.getenv('OPENALEX_API_KEY')
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
            'OpenAlex API key unavailable: OPENALEX_API_KEY is unset and no key '
                .. 'could be read from the research-secret tier field '
                .. config.secret_field
                .. ' (secret unavailable — tier not yet populated?)'
        )
    else
        err = make_error(
            'not_configured',
            'OpenAlex API key not configured: set the OPENALEX_API_KEY environment '
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
---The key travels as a Bearer token (docs: query parameter and Bearer
---header work identically; the header keeps the key out of URLs).
---Returns the HTTP status and the raw body for any completed response
---(including error statuses, so callers can classify them), or nil
---plus a structured error when the request never completed.
---@param url string full URL
---@param api_key string
---@return integer|nil status
---@return string|OpenAlexError body raw response text, or an error table
local function default_transport(url, api_key)
    local cmd = {
        'curl',
        '--silent',
        '--show-error',
        '--max-time',
        tostring(REQUEST_TIMEOUT_SEC),
        '--header',
        'Authorization: Bearer ' .. api_key,
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
        return nil, make_error('http', ('OpenAlex request failed: %s'):format(detail))
    end
    return tonumber(status_text), body
end

---One API request, classified. OpenAlex error bodies carry string
---`error` and `message` fields; 404 is 'not_found', 429 is
---'rate_limited' (daily budget exhausted or >100 requests/second),
---401/403 are 'auth'. A 200 with an unparseable body is
---'invalid_response', never a silent empty table.
---@param url string full URL
---@param api_key string
---@return table|nil decoded decoded JSON body
---@return OpenAlexError|nil err
local function request_json(url, api_key)
    local transport = config.transport or default_transport
    local status, body = transport(url, api_key)
    if status == nil then
        ---@cast body OpenAlexError
        return nil, body
    end
    ---@cast body string
    if status == 200 then
        local ok, decoded = pcall(vim.json.decode, body)
        if not ok or type(decoded) ~= 'table' then
            return nil, make_error('invalid_response', 'OpenAlex response was not valid JSON')
        end
        return decoded, nil
    end
    local detail = ('HTTP %d'):format(status)
    local ok, decoded = pcall(vim.json.decode, body)
    if ok and type(decoded) == 'table' and type(decoded.message) == 'string' then
        detail = ('%s — %s'):format(detail, decoded.message)
    end
    local code = 'http'
    if status == 401 or status == 403 then
        code = 'auth'
    elseif status == 404 then
        code = 'not_found'
    elseif status == 429 then
        code = 'rate_limited'
        detail = detail .. ' (daily budget exhausted or request rate too high; usage: GET /rate-limit)'
    end
    local err = make_error(code, ('OpenAlex request failed: %s'):format(detail))
    err.status = status
    return nil, err
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
    if value:find('[#?%%]') ~= nil then
        return nil
    end
    return value
end

---Normalize an OpenAlex work ID as a user might type it: the bare
---key (W…) or the full https://openalex.org/W… URL. IDs are
---case-insensitive per the docs; the key is returned upper-cased.
---@param raw string
---@return string|nil key
local function normalize_work_id(raw)
    local value = vim.trim(raw)
    value = value:gsub('^https://openalex%.org/', '')
    if value:match('^[Ww]%d+$') == nil then
        return nil
    end
    return 'W' .. value:sub(2)
end

---Normalize an ORCID iD as a user might type it: the bare iD or the
---https://orcid.org/… URL. Returns nil when the shape is wrong.
---@param raw string
---@return string|nil orcid
local function normalize_orcid(raw)
    local value = vim.trim(raw)
    value = value:gsub('^https://orcid%.org/', '')
    if value:match('^%d%d%d%d%-%d%d%d%d%-%d%d%d%d%-%d%d%d[%dXx]$') == nil then
        return nil
    end
    return value:sub(1, -2) .. value:sub(-1):upper()
end

---An ISSN as a user might type it: four digits, a hyphen, three
---digits and a digit/X check character. Returns nil otherwise.
---@param raw string
---@return string|nil issn
local function normalize_issn(raw)
    local value = vim.trim(raw):upper()
    if value:match('^%d%d%d%d%-%d%d%d[%dX]$') == nil then
        return nil
    end
    return value
end

---The short key (W…/A…/S…) of a full OpenAlex ID URL, or nil.
---@param id_url any
---@return string|nil key
local function entity_key(id_url)
    if type(id_url) ~= 'string' then
        return nil
    end
    return id_url:match('^https://openalex%.org/([WAS]%d+)$')
end

---Normalize one raw work object into an OpenAlexWork. Every field is
---type-guarded: JSON null decodes to vim.NIL (truthy), and optional
---fields (doi, primary_location) may be absent entirely.
---@param hit table raw work from the API
---@return OpenAlexWork
local function normalize_work(hit)
    local record = { authors = {}, title = '(untitled)' }
    record.id = entity_key(hit.id) or ''
    if type(hit.id) == 'string' then
        record.url = hit.id
    end
    if type(hit.title) == 'string' then
        record.title = hit.title
    elseif type(hit.display_name) == 'string' then
        record.title = hit.display_name
    end
    if type(hit.doi) == 'string' then
        record.doi = (hit.doi:gsub('^https://doi%.org/', ''))
    end
    if type(hit.publication_year) == 'number' then
        record.year = hit.publication_year
    end
    if type(hit.type) == 'string' then
        record.type = hit.type
    end
    if type(hit.cited_by_count) == 'number' then
        record.cited_by_count = hit.cited_by_count
    end
    if type(hit.referenced_works_count) == 'number' then
        record.referenced_count = hit.referenced_works_count
    elseif type(hit.referenced_works) == 'table' then
        record.referenced_count = #hit.referenced_works
    end
    if type(hit.authorships) == 'table' then
        for _, authorship in ipairs(hit.authorships) do
            if type(authorship) == 'table' and type(authorship.author) == 'table' then
                local name = authorship.author.display_name
                if type(name) == 'string' then
                    record.authors[#record.authors + 1] = name
                end
            end
        end
    end
    local location = hit.primary_location
    if type(location) == 'table' and type(location.source) == 'table' then
        if type(location.source.display_name) == 'string' then
            record.source = location.source.display_name
        end
        record.source_id = entity_key(location.source.id)
    end
    return record
end

---Normalize one raw author object into an OpenAlexAuthor.
---@param hit table raw author from the API
---@return OpenAlexAuthor
local function normalize_author(hit)
    local record = { name = '(unnamed)' }
    record.id = entity_key(hit.id) or ''
    if type(hit.id) == 'string' then
        record.url = hit.id
    end
    if type(hit.display_name) == 'string' then
        record.name = hit.display_name
    end
    if type(hit.orcid) == 'string' then
        record.orcid = (hit.orcid:gsub('^https://orcid%.org/', ''))
    end
    if type(hit.works_count) == 'number' then
        record.works_count = hit.works_count
    end
    if type(hit.cited_by_count) == 'number' then
        record.cited_by_count = hit.cited_by_count
    end
    return record
end

---Normalize one raw source object into an OpenAlexSource.
---@param hit table raw source from the API
---@return OpenAlexSource
local function normalize_source(hit)
    local record = { issn = {}, name = '(unnamed)' }
    record.id = entity_key(hit.id) or ''
    if type(hit.id) == 'string' then
        record.url = hit.id
    end
    if type(hit.display_name) == 'string' then
        record.name = hit.display_name
    end
    if type(hit.issn_l) == 'string' then
        record.issn_l = hit.issn_l
    end
    if type(hit.issn) == 'table' then
        for _, issn in ipairs(hit.issn) do
            if type(issn) == 'string' then
                record.issn[#record.issn + 1] = issn
            end
        end
    end
    if type(hit.type) == 'string' then
        record.type = hit.type
    end
    if type(hit.works_count) == 'number' then
        record.works_count = hit.works_count
    end
    if type(hit.cited_by_count) == 'number' then
        record.cited_by_count = hit.cited_by_count
    end
    if type(hit.is_oa) == 'boolean' then
        record.is_oa = hit.is_oa
    end
    if type(hit.homepage_url) == 'string' then
        record.homepage_url = hit.homepage_url
    end
    local stats = hit.summary_stats
    if type(stats) == 'table' then
        if type(stats.h_index) == 'number' then
            record.h_index = stats.h_index
        end
        if type(stats['2yr_mean_citedness']) == 'number' then
            record.mean_citedness_2yr = stats['2yr_mean_citedness']
        end
    end
    return record
end

---Fetch one work (raw API object) by DOI or work ID with an
---already-resolved key.
---@param query string DOI or OpenAlex work ID
---@param api_key string
---@return table|nil raw raw work object
---@return OpenAlexError|nil err
local function fetch_work_raw(query, api_key)
    local work_id = normalize_work_id(query)
    local path
    if work_id ~= nil then
        path = ('/works/%s'):format(work_id)
    else
        local doi = normalize_doi(query)
        if doi == nil then
            return nil, make_error('invalid_argument', ('not a DOI or OpenAlex work ID: %s'):format(query))
        end
        path = ('/works/doi:%s'):format(doi)
    end
    local raw, err = request_json(config.api_base .. path, api_key)
    if not raw then
        return nil, err
    end
    if type(raw.id) ~= 'string' then
        return nil, make_error('invalid_response', 'OpenAlex work response carried no id')
    end
    return raw, nil
end

---@class OpenAlexListResult
---@field items table[] normalized records (works, sources, …)
---@field total integer the API's total result count for the query
---@field truncated boolean true when a module cap cut the set

---Fetch a list endpoint with cursor paging, bounded by the caller's
---limit and PAGES_MAX. The base URL must already carry its query
---string (search/filter/sort); per_page and cursor are appended
---here. A response whose `results` is absent or not a list is
---'invalid_response' — never a fabricated empty page.
---@param base_url string endpoint URL with query, no paging params
---@param limit integer max items to collect (>= 1)
---@param api_key string
---@param normalize function fn(raw) -> record
---@return OpenAlexListResult|nil result
---@return OpenAlexError|nil err
local function fetch_list(base_url, limit, api_key, normalize)
    assert(limit >= 1, 'limit must be positive')
    local items = {}
    local total = nil
    local cursor = '*'
    local more_pages = false
    for _ = 1, PAGES_MAX do
        local remaining = limit - #items
        if remaining <= 0 then
            break
        end
        local per_page = math.min(PER_PAGE_MAX, remaining)
        local separator = base_url:find('?', 1, true) ~= nil and '&' or '?'
        local url = ('%s%sper_page=%d&cursor=%s'):format(base_url, separator, per_page, url_encode(cursor))
        local decoded, err = request_json(url, api_key)
        if not decoded then
            return nil, err
        end
        if type(decoded.results) ~= 'table' then
            return nil, make_error('invalid_response', 'OpenAlex list response carried no results array')
        end
        local meta = type(decoded.meta) == 'table' and decoded.meta or {}
        if type(meta.count) == 'number' then
            total = meta.count
        end
        for _, raw in ipairs(decoded.results) do
            if type(raw) == 'table' then
                items[#items + 1] = normalize(raw)
            end
        end
        if type(meta.next_cursor) == 'string' and meta.next_cursor ~= '' and #items < limit then
            cursor = meta.next_cursor
            more_pages = true
        else
            more_pages = type(meta.next_cursor) == 'string' and meta.next_cursor ~= ''
            break
        end
    end
    if total == nil then
        total = #items
    end
    local truncated = more_pages or total > #items
    return { items = items, total = total, truncated = truncated }, nil
end

---Resolve a caller limit option against the module cap.
---@param opts table|nil caller options (may carry `limit`)
---@param default_limit integer
---@return integer|nil limit
---@return OpenAlexError|nil err
local function resolve_limit(opts, default_limit)
    if opts == nil or opts.limit == nil then
        return default_limit, nil
    end
    if type(opts.limit) ~= 'number' or opts.limit < 1 then
        return nil, make_error('invalid_argument', 'limit must be a positive number')
    end
    return math.min(math.floor(opts.limit), LIST_LIMIT_MAX), nil
end

---Resolve a DOI or OpenAlex work ID (W…) to a normalized record.
---@param query string DOI (10.…/…) or work ID (W…)
---@return OpenAlexWork|nil record
---@return OpenAlexError|nil err
function M.lookup(query)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'lookup needs a DOI or an OpenAlex work ID')
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local raw, err = fetch_work_raw(vim.trim(query), api_key)
    if not raw then
        return nil, err
    end
    return normalize_work(raw), nil
end

---Search works by free text (title/abstract/fulltext per the API's
---default search). Bounded: opts.limit (default LIST_LIMIT_DEFAULT,
---max LIST_LIMIT_MAX) with cursor paging behind it.
---@param query string search text
---@param opts? table { limit = integer }
---@return table|nil result { works, total, truncated }
---@return OpenAlexError|nil err
function M.search(query, opts)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'search needs a query string')
    end
    local limit, limit_err = resolve_limit(opts, LIST_LIMIT_DEFAULT)
    if not limit then
        return nil, limit_err
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local url = ('%s/works?search=%s'):format(config.api_base, url_encode(vim.trim(query)))
    local list, err = fetch_list(url, limit, api_key, normalize_work)
    if not list then
        return nil, err
    end
    return { total = list.total, truncated = list.truncated, works = list.items }, nil
end

---Resolve an author by ORCID iD (defaults to your own ORCID).
---@param orcid? string ORCID iD or orcid.org URL (nil = DEFAULT_ORCID)
---@return OpenAlexAuthor|nil author
---@return OpenAlexError|nil err
function M.author(orcid)
    local id = normalize_orcid(orcid or DEFAULT_ORCID)
    if id == nil then
        return nil, make_error('invalid_argument', ('not an ORCID iD: %s'):format(tostring(orcid)))
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local url = ('%s/authors/https://orcid.org/%s'):format(config.api_base, id)
    local raw, err = request_json(url, api_key)
    if not raw then
        if err ~= nil and err.code == 'not_found' then
            err.message = ('no OpenAlex author for ORCID %s'):format(id)
        end
        return nil, err
    end
    if type(raw.id) ~= 'string' then
        return nil, make_error('invalid_response', 'OpenAlex author response carried no id')
    end
    local author = normalize_author(raw)
    if author.id == '' then
        return nil, make_error('invalid_response', 'OpenAlex author response carried an unparseable id')
    end
    return author, nil
end

---Read an author's works by ORCID (defaults to your own ORCID),
---newest first. Bounded like M.search.
---@param orcid? string ORCID iD or orcid.org URL (nil = DEFAULT_ORCID)
---@param opts? table { limit = integer }
---@return table|nil result { author, works, total, truncated }
---@return OpenAlexError|nil err
function M.author_works(orcid, opts)
    local limit, limit_err = resolve_limit(opts, LIST_LIMIT_DEFAULT)
    if not limit then
        return nil, limit_err
    end
    local author, author_err = M.author(orcid)
    if not author then
        return nil, author_err
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local filter = ('authorships.author.id:%s'):format(author.id)
    local url = ('%s/works?filter=%s&sort=publication_year:desc'):format(config.api_base, filter)
    local list, err = fetch_list(url, limit, api_key, normalize_work)
    if not list then
        return nil, err
    end
    return { author = author, total = list.total, truncated = list.truncated, works = list.items }, nil
end

---Forward snowball: works that cite the given work (the API's
---`cites:` filter — incoming citations), most-cited first. The seed
---may be a DOI or a work ID; a DOI costs one lookup to resolve.
---@param query string DOI or OpenAlex work ID
---@param opts? table { limit = integer }
---@return table|nil result { works, total, truncated, seed_id }
---@return OpenAlexError|nil err
function M.cited_by(query, opts)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'cited_by needs a DOI or an OpenAlex work ID')
    end
    local limit, limit_err = resolve_limit(opts, LIST_LIMIT_DEFAULT)
    if not limit then
        return nil, limit_err
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local raw, err = fetch_work_raw(vim.trim(query), api_key)
    if not raw then
        return nil, err
    end
    local seed_id = entity_key(raw.id)
    if seed_id == nil then
        return nil, make_error('invalid_response', 'OpenAlex work response carried an unparseable id')
    end
    local url = ('%s/works?filter=cites:%s&sort=cited_by_count:desc'):format(config.api_base, seed_id)
    local list, list_err = fetch_list(url, limit, api_key, normalize_work)
    if not list then
        return nil, list_err
    end
    return { seed_id = seed_id, total = list.total, truncated = list.truncated, works = list.items }, nil
end

---Backward snowball: the works the given work references (its
---`referenced_works`), resolved to records in reference order.
---Resolution is capped at REFERENCES_RESOLVE_MAX IDs per call; the
---full reference count rides along as referenced_total, with
---truncated set when the cap cut the list.
---@param query string DOI or OpenAlex work ID
---@return table|nil result { works, referenced_total, truncated, seed_id }
---@return OpenAlexError|nil err
function M.references(query)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'references needs a DOI or an OpenAlex work ID')
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local raw, err = fetch_work_raw(vim.trim(query), api_key)
    if not raw then
        return nil, err
    end
    local seed_id = entity_key(raw.id)
    local referenced = type(raw.referenced_works) == 'table' and raw.referenced_works or {}
    local keys = {}
    for _, id_url in ipairs(referenced) do
        local key = entity_key(id_url)
        if key ~= nil and #keys < REFERENCES_RESOLVE_MAX then
            keys[#keys + 1] = key
        end
    end
    if #keys == 0 then
        return { referenced_total = #referenced, seed_id = seed_id, truncated = #referenced > 0, works = {} }, nil
    end
    local filter = ('openalex:%s'):format(table.concat(keys, '|'))
    local url = ('%s/works?filter=%s&per_page=%d'):format(config.api_base, filter, #keys)
    local decoded, req_err = request_json(url, api_key)
    if not decoded then
        return nil, req_err
    end
    if type(decoded.results) ~= 'table' then
        return nil, make_error('invalid_response', 'OpenAlex list response carried no results array')
    end
    local by_key = {}
    for _, hit in ipairs(decoded.results) do
        if type(hit) == 'table' then
            local record = normalize_work(hit)
            if record.id ~= '' then
                by_key[record.id] = record
            end
        end
    end
    local works = {}
    for _, key in ipairs(keys) do
        if by_key[key] ~= nil then
            works[#works + 1] = by_key[key]
        end
    end
    return {
        referenced_total = #referenced,
        seed_id = seed_id,
        truncated = #referenced > #keys,
        works = works,
    },
        nil
end

---Resolve one source (venue) by ISSN or OpenAlex source ID (S…).
---@param query string ISSN (####-####) or source ID (S…)
---@return OpenAlexSource|nil record
---@return OpenAlexError|nil err
function M.source(query)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'source needs an ISSN or an OpenAlex source ID')
    end
    local value = vim.trim(query)
    local path
    local issn = normalize_issn(value)
    if issn ~= nil then
        path = ('/sources/issn:%s'):format(issn)
    else
        local key = value:gsub('^https://openalex%.org/', '')
        if key:match('^[Ss]%d+$') ~= nil then
            path = ('/sources/%s'):format('S' .. key:sub(2))
        else
            return nil,
                make_error(
                    'invalid_argument',
                    ('not an ISSN or OpenAlex source ID: %s (use search_sources for free text)'):format(query)
                )
        end
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local raw, err = request_json(config.api_base .. path, api_key)
    if not raw then
        return nil, err
    end
    if type(raw.id) ~= 'string' then
        return nil, make_error('invalid_response', 'OpenAlex source response carried no id')
    end
    return normalize_source(raw), nil
end

---Search sources (venues) by free text. Bounded like M.search.
---@param query string search text
---@param opts? table { limit = integer }
---@return table|nil result { sources, total, truncated }
---@return OpenAlexError|nil err
function M.search_sources(query, opts)
    if type(query) ~= 'string' or vim.trim(query) == '' then
        return nil, make_error('invalid_argument', 'search_sources needs a query string')
    end
    local limit, limit_err = resolve_limit(opts, 10)
    if not limit then
        return nil, limit_err
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local url = ('%s/sources?search=%s'):format(config.api_base, url_encode(vim.trim(query)))
    local list, err = fetch_list(url, limit, api_key, normalize_source)
    if not list then
        return nil, err
    end
    return { sources = list.items, total = list.total, truncated = list.truncated }, nil
end

---Venue ranking composed from /works group_by counts on
---primary_location.source.id: which sources carry the most works in
---a set. opts.filter is an optional raw OpenAlex filter string
---(e.g. 'type:article,from_publication_date:2020-01-01'); with no
---filter the ranking spans all of OpenAlex, which is rarely what you
---want — pass a filter. Capped at VENUE_GROUPS_MAX groups.
---@param opts? table { filter = string, limit = integer }
---@return table|nil result { venues, total_groups, truncated }
---@return OpenAlexError|nil err
function M.venue_ranking(opts)
    local limit = VENUE_GROUPS_MAX
    if opts ~= nil and opts.limit ~= nil then
        local resolved, limit_err = resolve_limit(opts, VENUE_GROUPS_MAX)
        if not resolved then
            return nil, limit_err
        end
        limit = math.min(resolved, VENUE_GROUPS_MAX)
    end
    local api_key, key_err = get_api_key()
    if not api_key then
        return nil, key_err
    end
    local url = ('%s/works?group_by=primary_location.source.id&per_page=%d'):format(config.api_base, limit)
    if opts ~= nil and type(opts.filter) == 'string' and opts.filter ~= '' then
        url = url .. '&filter=' .. url_encode(opts.filter)
    end
    local decoded, err = request_json(url, api_key)
    if not decoded then
        return nil, err
    end
    if type(decoded.group_by) ~= 'table' then
        return nil, make_error('invalid_response', 'OpenAlex group_by response carried no group_by array')
    end
    local venues = {}
    for _, group in ipairs(decoded.group_by) do
        if type(group) == 'table' and type(group.count) == 'number' then
            venues[#venues + 1] = {
                count = group.count,
                source_id = entity_key(group.key) or '',
                source_name = type(group.key_display_name) == 'string' and group.key_display_name or '(unknown source)',
            }
        end
    end
    local total_groups = #venues
    if type(decoded.meta) == 'table' and type(decoded.meta.count) == 'number' then
        total_groups = decoded.meta.count
    end
    return { total_groups = total_groups, truncated = total_groups > #venues, venues = venues }, nil
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

---@param record OpenAlexWork
---@return string[]
local function work_lines(record)
    local lines = {
        ('## %s'):format(record.title),
        '',
        ('- OpenAlex ID: %s'):format(record.id),
        ('- Authors: %s'):format(#record.authors > 0 and table.concat(record.authors, '; ') or 'not recorded'),
        ('- Source: %s'):format(record.source or 'not recorded'),
        ('- Year: %s'):format(record.year ~= nil and tostring(record.year) or 'not recorded'),
        ('- Type: %s'):format(record.type or 'not recorded'),
        ('- DOI: %s'):format(record.doi or 'not recorded'),
        ('- Cited by: %s'):format(record.cited_by_count ~= nil and tostring(record.cited_by_count) or 'not recorded'),
        ('- References: %s'):format(
            record.referenced_count ~= nil and tostring(record.referenced_count) or 'not recorded'
        ),
        ('- Record: %s'):format(record.url or 'not recorded'),
    }
    return lines
end

---@param heading string
---@param works OpenAlexWork[]
---@param total integer
---@param truncated boolean
---@return string[]
local function works_list_lines(heading, works, total, truncated)
    local lines = { ('# %s'):format(heading), '' }
    lines[#lines + 1] = ('- Results: %d of %d%s'):format(#works, total, truncated and ' (truncated)' or '')
    if #works == 0 then
        lines[#lines + 1] = '(no works found)'
    end
    for _, work in ipairs(works) do
        local head = ('- %s'):format(work.title)
        if work.year ~= nil then
            head = head .. (' (%d)'):format(work.year)
        end
        lines[#lines + 1] = head
        lines[#lines + 1] = ('  - %s — cited by %s — doi:%s'):format(
            work.source or 'no source recorded',
            work.cited_by_count ~= nil and tostring(work.cited_by_count) or '?',
            work.doi or '?'
        )
    end
    return lines
end

---@param source OpenAlexSource
---@return string[]
local function source_lines(source)
    local lines = {
        ('## %s'):format(source.name),
        '',
        ('- OpenAlex ID: %s'):format(source.id),
        ('- Type: %s'):format(source.type or 'not recorded'),
        ('- ISSN-L: %s'):format(source.issn_l or 'not recorded'),
        ('- ISSNs: %s'):format(#source.issn > 0 and table.concat(source.issn, ', ') or 'not recorded'),
        ('- Works: %s'):format(source.works_count ~= nil and tostring(source.works_count) or 'not recorded'),
        ('- Cited by: %s'):format(source.cited_by_count ~= nil and tostring(source.cited_by_count) or 'not recorded'),
        ('- h-index: %s'):format(source.h_index ~= nil and tostring(source.h_index) or 'not recorded'),
        ('- 2yr mean citedness: %s'):format(
            source.mean_citedness_2yr ~= nil and tostring(source.mean_citedness_2yr) or 'not recorded'
        ),
        ('- Open access: %s'):format(source.is_oa ~= nil and tostring(source.is_oa) or 'not recorded'),
        ('- Homepage: %s'):format(source.homepage_url or 'not recorded'),
        ('- Record: %s'):format(source.url or 'not recorded'),
    }
    return lines
end

---Show one work in a scratch buffer.
---@param query string DOI or work ID
---@return nil
function M.show_lookup(query)
    local record, err = M.lookup(query)
    if not record then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    show_lines('OpenAlex Work', work_lines(record))
end

---Show a works search in a scratch buffer.
---@param query string search text
---@return nil
function M.show_search(query)
    local result, err = M.search(query)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    show_lines(
        'OpenAlex Search',
        works_list_lines('OpenAlex — ' .. query, result.works, result.total, result.truncated)
    )
end

---Show an author's works in a scratch buffer.
---@param orcid? string ORCID iD (nil = your own)
---@return nil
function M.show_author_works(orcid)
    local result, err = M.author_works(orcid)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    local author = result.author
    local lines = {
        ('# OpenAlex — works by %s'):format(author.name),
        '',
        ('- ORCID: %s'):format(author.orcid or 'not recorded'),
        ('- OpenAlex author: %s (%s works, cited by %s)'):format(
            author.id,
            author.works_count ~= nil and tostring(author.works_count) or '?',
            author.cited_by_count ~= nil and tostring(author.cited_by_count) or '?'
        ),
        '',
    }
    local body = works_list_lines('Works', result.works, result.total, result.truncated)
    for index = 3, #body do
        lines[#lines + 1] = body[index]
    end
    show_lines('OpenAlex Author Works', lines)
end

---Show the works citing a seed work in a scratch buffer.
---@param query string DOI or work ID
---@return nil
function M.show_cited_by(query)
    local result, err = M.cited_by(query)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    local heading = ('OpenAlex — works citing %s'):format(result.seed_id)
    show_lines('OpenAlex Cited By', works_list_lines(heading, result.works, result.total, result.truncated))
end

---Show a seed work's references in a scratch buffer.
---@param query string DOI or work ID
---@return nil
function M.show_references(query)
    local result, err = M.references(query)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    local heading = ('OpenAlex — references of %s'):format(tostring(result.seed_id))
    show_lines(
        'OpenAlex References',
        works_list_lines(heading, result.works, result.referenced_total, result.truncated)
    )
end

---Show one source in a scratch buffer, resolving free text through
---search when the argument is neither an ISSN nor a source ID.
---@param query string ISSN, source ID, or venue name text
---@return nil
function M.show_source(query)
    local trimmed = type(query) == 'string' and vim.trim(query) or ''
    if normalize_issn(trimmed) ~= nil or trimmed:match('^[Ss]%d+$') ~= nil then
        local record, err = M.source(trimmed)
        if not record then
            notify_error(('OpenAlex: %s'):format(err.message))
            return
        end
        show_lines('OpenAlex Source', source_lines(record))
        return
    end
    local result, err = M.search_sources(query)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    local lines = { '# OpenAlex — sources matching ' .. query, '' }
    lines[#lines + 1] = ('- Results: %d of %d%s'):format(
        #result.sources,
        result.total,
        result.truncated and ' (truncated)' or ''
    )
    if #result.sources == 0 then
        lines[#lines + 1] = '(no sources found)'
    end
    for _, source in ipairs(result.sources) do
        lines[#lines + 1] = ('- %s (%s)'):format(source.name, source.id)
        lines[#lines + 1] = ('  - works %s, cited by %s, h-index %s, ISSN-L %s'):format(
            source.works_count ~= nil and tostring(source.works_count) or '?',
            source.cited_by_count ~= nil and tostring(source.cited_by_count) or '?',
            source.h_index ~= nil and tostring(source.h_index) or '?',
            source.issn_l or '?'
        )
    end
    show_lines('OpenAlex Sources', lines)
end

---Show a venue ranking in a scratch buffer.
---@param filter string|nil raw OpenAlex filter string ('' = none)
---@return nil
function M.show_venues(filter)
    local opts = nil
    if filter ~= nil and filter ~= '' then
        opts = { filter = filter }
    end
    local result, err = M.venue_ranking(opts)
    if not result then
        notify_error(('OpenAlex: %s'):format(err.message))
        return
    end
    local lines = { '# OpenAlex — venue ranking by works count', '' }
    lines[#lines + 1] = ('- Groups: %d of %d%s'):format(
        #result.venues,
        result.total_groups,
        result.truncated and ' (truncated)' or ''
    )
    if #result.venues == 0 then
        lines[#lines + 1] = '(no venues in this set)'
    end
    for _, venue in ipairs(result.venues) do
        lines[#lines + 1] = ('- %s (%s): %d works'):format(venue.source_name, venue.source_id, venue.count)
    end
    show_lines('OpenAlex Venue Ranking', lines)
end

---@param opts? OpenAlexConfig partial overrides (api_base, api_key, secret_field, transport)
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

    api.nvim_create_user_command('OpenAlexCitedBy', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('OpenAlex: usage :OpenAlexCitedBy <doi-or-work-id>', vim.log.levels.WARN)
            return
        end
        M.show_cited_by(query)
    end, {
        nargs = '?',
        desc = 'Show works citing a DOI or OpenAlex work ID',
    })

    api.nvim_create_user_command('OpenAlexLookup', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('OpenAlex: usage :OpenAlexLookup <doi-or-work-id>', vim.log.levels.WARN)
            return
        end
        M.show_lookup(query)
    end, {
        nargs = '?',
        desc = 'Look up a DOI or OpenAlex work ID',
    })

    api.nvim_create_user_command('OpenAlexReferences', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('OpenAlex: usage :OpenAlexReferences <doi-or-work-id>', vim.log.levels.WARN)
            return
        end
        M.show_references(query)
    end, {
        nargs = '?',
        desc = 'Show the references of a DOI or OpenAlex work ID',
    })

    api.nvim_create_user_command('OpenAlexSearch', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('OpenAlex: usage :OpenAlexSearch <query>', vim.log.levels.WARN)
            return
        end
        M.show_search(query)
    end, {
        nargs = '?',
        desc = 'Search OpenAlex works by free text',
    })

    api.nvim_create_user_command('OpenAlexSource', function(cmd_opts)
        local query = vim.trim(cmd_opts.args or '')
        if query == '' then
            vim.notify('OpenAlex: usage :OpenAlexSource <issn-or-source-id-or-name>', vim.log.levels.WARN)
            return
        end
        M.show_source(query)
    end, {
        nargs = '?',
        desc = 'Look up an OpenAlex source (venue) by ISSN, ID, or name',
    })

    api.nvim_create_user_command('OpenAlexVenues', function(cmd_opts)
        local filter = vim.trim(cmd_opts.args or '')
        M.show_venues(filter)
    end, {
        nargs = '?',
        desc = 'Rank venues by works count (optional OpenAlex filter)',
    })

    api.nvim_create_user_command('OpenAlexWorks', function(cmd_opts)
        local orcid = vim.trim(cmd_opts.args or '')
        if orcid == '' then
            M.show_author_works(nil)
        else
            M.show_author_works(orcid)
        end
    end, {
        nargs = '?',
        desc = 'Show OpenAlex works for an ORCID (default: yours)',
    })
end

return M
