-- /qompassai/Diver/lua/research/watchlist.lua
-- Qompass AI Diver Research Watchlist Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Grants and competitions watchlist monitor: polls the sources named in
-- the watched entries, diffs each result against the last-seen snapshot
-- stored in the state file, and surfaces what is new, what changed (a
-- close date announced or moved, a reward changed), and what closed or
-- disappeared.
--
-- Sources and their verified contracts (checked against the primary
-- documentation on 2026-10-08):
--
--   * Simpler.Grants.gov -- POST /v1/opportunities/search on
--     https://api.simpler.grants.gov with the API key in the X-API-Key
--     header (the legacy X-Auth header was removed upstream). Every
--     filter value is a one_of object; the CDMRP programs (PRORP,
--     PRMRP) are covered by assistance_listing_number 12.420.
--     Pagination is required in the request body (page_offset is
--     1-based, page_size at most 100). Published limits: 60 requests
--     per minute and 10,000 per day; a key auto-disables after 30
--     days without use. The free-text query is capped at 100
--     characters by the API.
--   * Kaggle -- GET /api/v1/competitions/list on
--     https://www.kaggle.com, HTTP Basic auth with the account
--     username and API key. List items carry ref, deadline, category,
--     reward, and teamCount; an item's stable identifier is the
--     competition slug at the end of its ref URL.
--
-- Deliberate design points:
--
--   * State lives in one operator-owned JSON file (default
--     ~/.local/share/diver/research-watchlist.json): the watched
--     entries plus, per entry, the last-seen snapshot. A missing file
--     seeds the default watches in memory; the file is first written
--     by a check. A malformed file is a structured error, never a
--     crash and never a silent reset.
--   * Alert-once: the snapshot update is the dedup mechanism. A diff
--     is computed against the stored snapshot and the snapshot is then
--     replaced, so an unchanged diff never re-alerts and a change
--     alerts exactly once. A watch with no snapshot yet records a
--     baseline silently -- the first check never floods alerts for
--     everything that already exists.
--   * 'closed' is only classified when the fetch was complete: a
--     truncated result cannot distinguish 'gone' from 'beyond the
--     cap', so closed alerts are suppressed for truncated watches.
--     For Kaggle, whose recent-first listing rotates live items out
--     of the fetched window, an absent item additionally counts as
--     closed only once its deadline has passed.
--   * Per-source degradation: a missing Grants.gov key disables only
--     the grants watches and a missing Kaggle credential only the
--     kaggle watches; a check with one source keyed still runs the
--     other. Nothing is ever fabricated for an unavailable source.
--   * Bounded work: watches, pages per watch, items per snapshot,
--     and total requests per check are all capped; anything cut off
--     is reported as truncated, never presented as complete. Request
--     counts stay far inside the published Grants.gov limits for a
--     manual or timer-driven check.
--   * No timer is installed by this module: a check runs from
--     :WatchlistCheck or headlessly via require(...).check_and_print();
--     scheduling one is a separate, explicit decision.
--   * DoD SBIR/STTR solicitations are intentionally absent: they are
--     published through DSIP, which has no API, so any watch entry
--     for them would be fiction. They stay a manual watch.
--
-- Public API:
--   check()          -> result | nil, err
--   check_and_print()-> result | nil, err (check, printing alert lines)
--   default_watches()-> the seeded watch entries (no snapshots)
--   format_check(result) / format_watchlist(state) -> display lines
--   load_state()     -> state | nil, err
--   save_state(state)-> true | nil, err
--   setup(opts)      -> register the user commands (run by init.lua)

local api = vim.api
local assert = assert
local fn = vim.fn
local ipairs = ipairs
local json_decode = vim.json.decode
local json_encode = vim.json.encode
local math_floor = math.floor
local pairs = pairs
local pcall = pcall
local string_format = string.format
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type

local M = {}

local ALERTS_NOTIFY_MAX = 10
local API_BASE_GRANTS = 'https://api.simpler.grants.gov'
local API_BASE_KAGGLE = 'https://www.kaggle.com/api/v1'
local API_KEY_HEADER = 'X-API-Key'
local CURL_TIMEOUT_SECONDS = 30
local ENV_GRANTS_KEY = 'SIMPLE_GRANTS_API_KEY'
local ENV_KAGGLE_KEY = 'KAGGLE_KEY'
local ENV_KAGGLE_USERNAME = 'KAGGLE_USERNAME'
local GRANTS_PAGE_SIZE = 50
local ITEMS_DISPLAY_MAX = 10
local ITEMS_PER_WATCH_MAX = 200
local PAGES_MAX = 4
local QUERY_CHARS_MAX = 100
local REQUESTS_PER_CHECK_MAX = 40
local STATE_BYTES_MAX = 524288
local STATE_SCHEMA_VERSION = 1
local STATUS_MARKER = '__WATCHLIST_HTTP_STATUS__:'
local TITLE_CHARS_MAX = 240
local WATCHES_MAX = 16

---@class research.watchlist.Request
---@field method string HTTP method ('GET' or 'POST').
---@field url string Fully built request URL.
---@field headers table<string, string> Header name to value map.
---@field body string|nil JSON request body for POSTs.

---@class research.watchlist.Error
---@field code string Machine-stable error code.
---@field message string Human-readable detail.
---@field source string|nil Source the error belongs to ('grants' or 'kaggle').
---@field status integer|nil HTTP status when the error came from a response.
---@field sources_tried string[]|nil Secret resolution chain, for secret errors.

---@class research.watchlist.Item
---@field id string Stable per-source identifier.
---@field title string Display title (bounded length).
---@field closes string|nil Close/deadline date, 'YYYY-MM-DD', when known.
---@field reward string|nil Reward text (Kaggle), when the source reports one.
---@field category string|nil Kaggle category, when reported.
---@field status string|nil Grants.gov opportunity status, when reported.
---@field detail string|nil Grants.gov opportunity number, when reported.

---@class research.watchlist.Snapshot
---@field checked_at string UTC timestamp of the check that produced it.
---@field items research.watchlist.Item[] Last-seen items for the watch.

---@class research.watchlist.Watch
---@field id string Unique watch identifier.
---@field source string 'grants' or 'kaggle'.
---@field label string Human-readable label.
---@field query string|nil Grants.gov free-text query.
---@field query_operator string|nil Grants.gov query operator ('AND' or 'OR').
---@field assistance_listing string|nil Grants.gov assistance listing number.
---@field statuses string[]|nil Grants.gov opportunity statuses to include.
---@field search string|nil Kaggle list search text.
---@field sort_by string|nil Kaggle list sort order.
---@field category string|nil Kaggle competition category.
---@field snapshot research.watchlist.Snapshot|nil Last-seen snapshot.

---@class research.watchlist.Alert
---@field watch_id string Watch that produced the alert.
---@field source string Source of the watch.
---@field kind string 'new', 'date_changed', 'reward_changed', or 'closed'.
---@field item_id string Identifier of the item.
---@field title string Item title.
---@field closes string|nil Current close date, when known.
---@field reward string|nil Current reward, when reported.
---@field previous_closes string|nil Snapshot close date (date_changed).
---@field previous_reward string|nil Snapshot reward (reward_changed).

---@class research.watchlist.WatchResult
---@field id string Watch identifier.
---@field source string Watch source.
---@field label string Watch label.
---@field status string 'ok' or 'error'.
---@field baseline boolean True when this check recorded the first snapshot.
---@field items_found integer Items in the current result.
---@field total integer|nil Source-reported total, when it reports one.
---@field truncated boolean True when caps cut the result short.
---@field alerts research.watchlist.Alert[] Alerts from this watch.
---@field error research.watchlist.Error|nil Structured error, when failed.

---@class research.watchlist.CheckResult
---@field checked_at string UTC timestamp of the check.
---@field saved boolean True when the updated state was persisted.
---@field watches research.watchlist.WatchResult[] Per-watch outcomes.
---@field alerts research.watchlist.Alert[] All alerts, in watch order.
---@field errors research.watchlist.Error[] All per-watch errors.

---@class research.watchlist.Config
---@field api_base_grants string Simpler.Grants.gov API base URL.
---@field api_base_kaggle string Kaggle API base URL.
---@field grants_api_key string|nil Setup-provided Grants.gov key seam.
---@field kaggle_key string|nil Setup-provided Kaggle key seam.
---@field kaggle_username string|nil Setup-provided Kaggle username seam.
---@field kaggle_config_path string Path of the kaggle.json credentials file.
---@field secret_field_grants string Research-tier field for the Grants.gov key.
---@field secret_field_kaggle_key string Research-tier field for the Kaggle key.
---@field secret_field_kaggle_username string Tier field for the Kaggle username.
---@field secret_tier_program string Absolute path of the tier reader program.
---@field state_path string Path of the watchlist state file.
---@field transport (fun(request: research.watchlist.Request): integer|nil, string)|nil

---@type research.watchlist.Config
local config = {
    api_base_grants = API_BASE_GRANTS,
    api_base_kaggle = API_BASE_KAGGLE,
    grants_api_key = nil,
    kaggle_key = nil,
    kaggle_username = nil,
    kaggle_config_path = fn.expand('~/.kaggle/kaggle.json'),
    secret_field_grants = 'grants_gov_api_key',
    secret_field_kaggle_key = 'kaggle_key',
    secret_field_kaggle_username = 'kaggle_username',
    secret_tier_program = fn.expand('~/.local/bin/research-secret'),
    state_path = fn.expand('~/.local/share/diver/research-watchlist.json'),
    transport = nil,
}

-- ---------------------------------------------------------------------
-- Validation helpers
-- ---------------------------------------------------------------------

--- True when a decoded JSON value is a list (sequential integer keys).
---@param value any
---@return boolean
local function is_array(value)
    if type(value) ~= 'table' then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or math_floor(key) ~= key then
            return false
        end
        count = count + 1
    end
    return count == #value
end

--- Reads an optional string field; JSON nulls and non-strings become nil.
---@param source table
---@param name string
---@return string|nil
local function optional_string(source, name)
    local value = source[name]
    if type(value) ~= 'string' or value == '' then
        return nil
    end
    return value
end

--- Builds a structured module error.
---@param code string
---@param message string
---@param source string|nil
---@return research.watchlist.Error
local function make_error(code, message, source)
    return { code = code, message = message, source = source }
end

--- Extracts a leading 'YYYY-MM-DD' date from a source date/timestamp.
---@param value string|nil
---@return string|nil
local function date_prefix(value)
    if value == nil then
        return nil
    end
    return string_match(value, '^%d%d%d%d%-%d%d%-%d%d') and string_sub(value, 1, 10) or nil
end

--- Bounds a stored title so one bad payload cannot bloat the state file.
---@param title string
---@return string
local function bound_title(title)
    if #title > TITLE_CHARS_MAX then
        return string_sub(title, 1, TITLE_CHARS_MAX)
    end
    return title
end

--- Current UTC timestamp in the stored ISO-8601 shape. The tostring
--- is a runtime no-op for a string format; it exists because LuaLS
--- models os.date's return as string|osdate.
---@return string
local function utc_now()
    return tostring(os.date('!%Y-%m-%dT%H:%M:%SZ'))
end

--- Current UTC date, for the Kaggle closed-classification rule.
---@return string
local function utc_today()
    return tostring(os.date('!%Y-%m-%d'))
end

-- ---------------------------------------------------------------------
-- Secret resolution (house chain: env, tier, setup seam)
-- ---------------------------------------------------------------------

--- Reads one field from the sops research tier via the tier program.
--- The tier program pins its own age key; a field that is missing,
--- empty, or still the REPLACE_ME placeholder counts as unavailable,
--- exactly as an operator who has not populated it yet would expect.
---@param field string
---@return string|nil
local function get_research_secret(field)
    assert(type(field) == 'string' and field ~= '', 'tier field name is required')
    local argv = { config.secret_tier_program, field }
    if fn.executable(argv[1]) ~= 1 then
        return nil
    end
    local output = fn.system(argv)
    if vim.v.shell_error ~= 0 or type(output) ~= 'string' then
        return nil
    end
    if string_sub(output, -1) == '\n' then
        output = string_sub(output, 1, -2)
    end
    if output == '' or output == 'REPLACE_ME' then
        return nil
    end
    return output
end

--- Resolves the Simpler.Grants.gov API key: SIMPLE_GRANTS_API_KEY
--- env, then the sops research tier, then the setup() seam. The API
--- itself takes the key in the X-API-Key header (see request build).
---@return string|nil key
---@return research.watchlist.Error|nil err
local function grants_api_key()
    local sources_tried = { 'env' }
    local env_key = fn.getenv(ENV_GRANTS_KEY)
    if type(env_key) == 'string' and env_key ~= '' then
        return env_key, nil
    end
    table_insert(sources_tried, 'tier')
    local tier_key = get_research_secret(config.secret_field_grants)
    if tier_key ~= nil then
        return tier_key, nil
    end
    if type(config.grants_api_key) == 'string' and config.grants_api_key ~= '' then
        return config.grants_api_key, nil
    end
    local err = make_error(
        'secret_unavailable',
        'Simpler.Grants.gov API key unavailable: set '
            .. ENV_GRANTS_KEY
            .. ', populate the research tier field '
            .. config.secret_field_grants
            .. ' (register a key at simpler.grants.gov/developers),'
            .. ' or pass grants_api_key to setup()',
        'grants'
    )
    err.sources_tried = sources_tried
    return nil, err
end

--- Reads and parses the Kaggle credentials file, when present.
---@return table|nil credentials
---@return research.watchlist.Error|nil err
local function kaggle_file_credentials()
    if fn.filereadable(config.kaggle_config_path) ~= 1 then
        return nil, nil
    end
    local lines = fn.readfile(config.kaggle_config_path, '', 64)
    local ok, decoded = pcall(json_decode, table_concat(lines, '\n'))
    if not ok or type(decoded) ~= 'table' then
        return nil,
            make_error(
                'invalid_argument',
                'Kaggle credentials file exists but is not valid JSON: ' .. config.kaggle_config_path,
                'kaggle'
            )
    end
    local username = optional_string(decoded, 'username')
    local key = optional_string(decoded, 'key')
    if username == nil or key == nil then
        return nil,
            make_error(
                'invalid_argument',
                'Kaggle credentials file lacks a username/key pair: ' .. config.kaggle_config_path,
                'kaggle'
            )
    end
    return { username = username, key = key }, nil
end

--- Resolves the Kaggle username/key pair: the KAGGLE_USERNAME /
--- KAGGLE_KEY env pair, then ~/.kaggle/kaggle.json read at call time
--- (never cached or copied), then the sops research tier pair, then
--- the setup() seam. A present-but-malformed credentials file is a
--- hard per-source error: silently falling through would hide it.
---@return table|nil credentials
---@return research.watchlist.Error|nil err
local function kaggle_credentials()
    local sources_tried = { 'env' }
    local env_username = fn.getenv(ENV_KAGGLE_USERNAME)
    local env_key = fn.getenv(ENV_KAGGLE_KEY)
    if type(env_username) == 'string' and env_username ~= '' and type(env_key) == 'string' and env_key ~= '' then
        return { username = env_username, key = env_key }, nil
    end
    table_insert(sources_tried, 'file')
    local file_credentials, file_err = kaggle_file_credentials()
    if file_err ~= nil then
        return nil, file_err
    end
    if file_credentials ~= nil then
        return file_credentials, nil
    end
    table_insert(sources_tried, 'tier')
    local tier_username = get_research_secret(config.secret_field_kaggle_username)
    local tier_key = get_research_secret(config.secret_field_kaggle_key)
    if tier_username ~= nil and tier_key ~= nil then
        return { username = tier_username, key = tier_key }, nil
    end
    if
        type(config.kaggle_username) == 'string'
        and config.kaggle_username ~= ''
        and type(config.kaggle_key) == 'string'
        and config.kaggle_key ~= ''
    then
        return { username = config.kaggle_username, key = config.kaggle_key }, nil
    end
    local err = make_error(
        'secret_unavailable',
        'Kaggle credentials unavailable: set '
            .. ENV_KAGGLE_USERNAME
            .. ' and '
            .. ENV_KAGGLE_KEY
            .. ', create '
            .. config.kaggle_config_path
            .. ' (kaggle.com Settings -> API -> Create New Token), populate the'
            .. ' research tier fields '
            .. config.secret_field_kaggle_username
            .. ' and '
            .. config.secret_field_kaggle_key
            .. ', or pass kaggle_username and kaggle_key to setup()',
        'kaggle'
    )
    err.sources_tried = sources_tried
    return nil, err
end

-- ---------------------------------------------------------------------
-- HTTP transport and request plumbing
-- ---------------------------------------------------------------------

--- Default curl transport. argv form only (no shell); the status line
--- is appended by curl's write-out and parsed back off, so an HTTP
--- error status is data, not a process failure.
---@param request research.watchlist.Request
---@return integer|nil status
---@return string body
local function curl_transport(request)
    assert(type(request.url) == 'string' and request.url ~= '', 'request URL is required')
    local argv = {
        'curl',
        '--silent',
        '--show-error',
        '--max-time',
        tostring(CURL_TIMEOUT_SECONDS),
        '--request',
        request.method,
        '--write-out',
        '\n' .. STATUS_MARKER .. '%{http_code}',
    }
    local header_names = {}
    for name in pairs(request.headers) do
        table_insert(header_names, name)
    end
    table_sort(header_names)
    for _, name in ipairs(header_names) do
        table_insert(argv, '--header')
        table_insert(argv, name .. ': ' .. request.headers[name])
    end
    if request.body ~= nil then
        table_insert(argv, '--data')
        table_insert(argv, request.body)
    end
    table_insert(argv, request.url)
    if fn.executable('curl') ~= 1 then
        return nil, 'curl executable not found'
    end
    local output = fn.system(argv)
    if vim.v.shell_error ~= 0 then
        return nil, 'curl failed with exit status ' .. tostring(vim.v.shell_error)
    end
    local marker_at = output:find(STATUS_MARKER, 1, true)
    if marker_at == nil then
        return nil, 'curl output lacked an HTTP status marker'
    end
    local status_number = tonumber(string_sub(output, marker_at + #STATUS_MARKER))
    local status = status_number ~= nil and math_floor(status_number) or nil
    local body = string_sub(output, 1, marker_at - 1)
    if string_sub(body, -1) == '\n' then
        body = string_sub(body, 1, -2)
    end
    return status, body
end

--- Runs one request through the configured transport and classifies
--- the outcome. Returns the decoded JSON value on HTTP 200.
---@param request research.watchlist.Request
---@param source string
---@return any decoded
---@return research.watchlist.Error|nil err
local function request_json(request, source)
    local transport = config.transport or curl_transport
    local status, body = transport(request)
    if status == nil then
        return nil, make_error('http', 'transport failed: ' .. tostring(body), source)
    end
    assert(type(body) == 'string', 'transport must return a body string')
    if status == 401 or status == 403 then
        local err = make_error('auth', 'HTTP ' .. status .. ': API key rejected', source)
        err.status = status
        return nil, err
    end
    if status == 429 then
        local err = make_error('rate_limited', 'HTTP 429: rate limit or daily budget reached', source)
        err.status = status
        return nil, err
    end
    if status ~= 200 then
        local err = make_error('http', 'HTTP ' .. status .. ': ' .. string_sub(body, 1, 200), source)
        err.status = status
        return nil, err
    end
    local ok, decoded = pcall(json_decode, body)
    if not ok then
        return nil, make_error('invalid_response', 'response body was not valid JSON', source)
    end
    return decoded, nil
end

--- Percent-encodes one query-string value.
---@param value string
---@return string
local function url_encode(value)
    local encoded = value:gsub('[^%w%-%.%_%~]', function(char)
        return string_format('%%%02X', char:byte())
    end)
    return encoded
end

-- ---------------------------------------------------------------------
-- Response normalization
-- ---------------------------------------------------------------------

--- Normalizes one Simpler.Grants.gov opportunity object. Items with no
--- opportunity_id cannot be diffed and are dropped.
---@param raw any
---@return research.watchlist.Item|nil
local function grants_item(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    local id = optional_string(raw, 'opportunity_id')
    if id == nil then
        return nil
    end
    local title = optional_string(raw, 'opportunity_title') or '(untitled opportunity)'
    return {
        id = id,
        title = bound_title(title),
        closes = date_prefix(optional_string(raw, 'close_date')),
        status = optional_string(raw, 'opportunity_status'),
        detail = optional_string(raw, 'opportunity_number'),
    }
end

--- Normalizes one Kaggle competition object. The stable identifier is
--- the slug at the end of the ref URL; the numeric id is the fallback.
---@param raw any
---@return research.watchlist.Item|nil
local function kaggle_item(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    local id = nil
    local ref = optional_string(raw, 'ref')
    if ref ~= nil then
        id = string_match(ref, '/competitions/([^/?#]+)/?$')
    end
    if id == nil and raw.id ~= nil and (type(raw.id) == 'number' or type(raw.id) == 'string') then
        id = tostring(raw.id)
    end
    if id == nil then
        return nil
    end
    local title = optional_string(raw, 'title') or id
    local reward = raw.reward
    if type(reward) == 'number' then
        reward = tostring(reward)
    elseif type(reward) ~= 'string' then
        reward = nil
    end
    return {
        id = id,
        title = bound_title(title),
        closes = date_prefix(optional_string(raw, 'deadline')),
        reward = reward,
        category = optional_string(raw, 'category'),
    }
end

-- ---------------------------------------------------------------------
-- Source fetchers (budget-counted, paged, capped)
-- ---------------------------------------------------------------------

--- Runs one request against the per-check budget. The budget is what
--- keeps a pathological watch list inside the published rate limits.
---@param budget table
---@param request research.watchlist.Request
---@param source string
---@return any decoded
---@return research.watchlist.Error|nil err
local function budgeted_request(budget, request, source)
    if budget.remaining <= 0 then
        return nil, make_error('request_budget', 'per-check request budget exhausted', source)
    end
    budget.remaining = budget.remaining - 1
    return request_json(request, source)
end

--- Builds the Grants.gov search body for one page of a watch.
---@param watch research.watchlist.Watch
---@param page_offset integer
---@return table
local function grants_search_body(watch, page_offset)
    local filters = {}
    local statuses = watch.statuses or { 'forecasted', 'posted' }
    filters.opportunity_status = { one_of = statuses }
    if watch.assistance_listing ~= nil then
        filters.assistance_listing_number = { one_of = { watch.assistance_listing } }
    end
    local body = {
        filters = filters,
        pagination = {
            page_offset = page_offset,
            page_size = GRANTS_PAGE_SIZE,
            sort_order = { { order_by = 'close_date', sort_direction = 'ascending' } },
        },
    }
    if watch.query ~= nil then
        body.query = watch.query
    end
    if watch.query_operator ~= nil then
        body.query_operator = watch.query_operator
    end
    return body
end

--- Fetches one grants watch: pages of opportunity search until the
--- result is complete or a cap cuts it (reported via truncated).
--- Items are deduped by id across pages: a listing that shifts while
--- paging can repeat an item, and a snapshot never holds one twice.
---@param watch research.watchlist.Watch
---@param key string
---@param budget table
---@return research.watchlist.Item[]|nil items
---@return integer|nil total
---@return boolean truncated
---@return research.watchlist.Error|nil err
local function fetch_grants(watch, key, budget)
    if watch.query ~= nil and #watch.query > QUERY_CHARS_MAX then
        return nil,
            nil,
            false,
            make_error(
                'invalid_argument',
                'watch query exceeds the API limit of ' .. QUERY_CHARS_MAX .. ' characters',
                'grants'
            )
    end
    local items = {}
    local seen_ids = {}
    local total = nil
    local truncated = false
    for page = 1, PAGES_MAX do
        local request = {
            method = 'POST',
            url = config.api_base_grants .. '/v1/opportunities/search',
            headers = {
                [API_KEY_HEADER] = key,
                ['Content-Type'] = 'application/json',
            },
            body = json_encode(grants_search_body(watch, page)),
        }
        local decoded, err = budgeted_request(budget, request, 'grants')
        if decoded == nil then
            if page == 1 then
                return nil, nil, false, err
            end
            truncated = true
            break
        end
        if type(decoded) ~= 'table' or not is_array(decoded.data) then
            return nil, nil, false, make_error('invalid_response', 'search response lacked a data array', 'grants')
        end
        if type(decoded.pagination_info) == 'table' and type(decoded.pagination_info.total_records) == 'number' then
            total = decoded.pagination_info.total_records
        end
        for _, raw in ipairs(decoded.data) do
            local item = grants_item(raw)
            if item ~= nil and not seen_ids[item.id] then
                seen_ids[item.id] = true
                if #items < ITEMS_PER_WATCH_MAX then
                    table_insert(items, item)
                else
                    truncated = true
                end
            end
        end
        if total ~= nil and #items >= total then
            break
        end
        if #decoded.data < GRANTS_PAGE_SIZE then
            break
        end
        if page == PAGES_MAX then
            truncated = true
        end
    end
    if total ~= nil and total > #items then
        truncated = true
    end
    return items, total, truncated, nil
end

--- Builds the Kaggle competitions list URL for one page of a watch.
---@param watch research.watchlist.Watch
---@param page integer
---@return string
local function kaggle_list_url(watch, page)
    local params = {
        'group=general',
        'category=' .. url_encode(watch.category or 'all'),
        'sortBy=' .. url_encode(watch.sort_by or 'recentlyCreated'),
    }
    if watch.search ~= nil and watch.search ~= '' then
        table_insert(params, 'search=' .. url_encode(watch.search))
    end
    table_insert(params, 'page=' .. tostring(page))
    return config.api_base_kaggle .. '/competitions/list?' .. table_concat(params, '&')
end

--- Builds the HTTP Basic authorization header for a Kaggle pair.
---@param username string
---@param key string
---@return string|nil header
---@return research.watchlist.Error|nil err
local function kaggle_auth_header(username, key)
    if vim.base64 == nil or vim.base64.encode == nil then
        return nil, make_error('http', 'this Neovim build lacks vim.base64', 'kaggle')
    end
    return 'Basic ' .. vim.base64.encode(username .. ':' .. key), nil
end

--- Fetches one kaggle watch: pages of the competitions list until a
--- short page ends the listing or a cap cuts it (reported).
---@param watch research.watchlist.Watch
---@param credentials table
---@param budget table
---@return research.watchlist.Item[]|nil items
---@return integer|nil total
---@return boolean truncated
---@return research.watchlist.Error|nil err
local function fetch_kaggle(watch, credentials, budget)
    local header, header_err = kaggle_auth_header(credentials.username, credentials.key)
    if header == nil then
        return nil, nil, false, header_err
    end
    local items = {}
    local seen_ids = {}
    local truncated = false
    local full_page_size = nil
    for page = 1, PAGES_MAX do
        local request = {
            method = 'GET',
            url = kaggle_list_url(watch, page),
            headers = { Authorization = header },
        }
        local decoded, err = budgeted_request(budget, request, 'kaggle')
        if decoded == nil then
            if page == 1 then
                return nil, nil, false, err
            end
            truncated = true
            break
        end
        if not is_array(decoded) then
            return nil, nil, false, make_error('invalid_response', 'list response was not a JSON array', 'kaggle')
        end
        if #decoded == 0 then
            break
        end
        if full_page_size == nil then
            full_page_size = #decoded
        end
        for _, raw in ipairs(decoded) do
            local item = kaggle_item(raw)
            if item ~= nil and not seen_ids[item.id] then
                seen_ids[item.id] = true
                if #items < ITEMS_PER_WATCH_MAX then
                    table_insert(items, item)
                else
                    truncated = true
                end
            end
        end
        if #decoded < full_page_size then
            break
        end
        if page == PAGES_MAX then
            truncated = true
        end
    end
    return items, nil, truncated, nil
end

-- ---------------------------------------------------------------------
-- Diffing
-- ---------------------------------------------------------------------

--- Diffs current items against the snapshot items. A nil snapshot is
--- a baseline: no alerts, by design. Closed classification follows
--- the module rules (complete fetch required; Kaggle items must also
--- be past their deadline).
---@param source string
---@param previous research.watchlist.Item[]|nil
---@param current research.watchlist.Item[]
---@param truncated boolean
---@param today string
---@return research.watchlist.Alert[]
local function diff_items(source, previous, current, truncated, today)
    local alerts = {}
    if previous == nil then
        return alerts
    end
    local previous_by_id = {}
    for _, item in ipairs(previous) do
        previous_by_id[item.id] = item
    end
    local seen = {}
    for _, item in ipairs(current) do
        seen[item.id] = true
        local old = previous_by_id[item.id]
        if old == nil then
            table_insert(alerts, {
                kind = 'new',
                item_id = item.id,
                title = item.title,
                closes = item.closes,
                reward = item.reward,
            })
        else
            if old.closes ~= item.closes then
                table_insert(alerts, {
                    kind = 'date_changed',
                    item_id = item.id,
                    title = item.title,
                    closes = item.closes,
                    reward = item.reward,
                    previous_closes = old.closes,
                })
            end
            if old.reward ~= item.reward then
                table_insert(alerts, {
                    kind = 'reward_changed',
                    item_id = item.id,
                    title = item.title,
                    closes = item.closes,
                    reward = item.reward,
                    previous_reward = old.reward,
                })
            end
        end
    end
    if not truncated then
        for _, item in ipairs(previous) do
            if not seen[item.id] then
                local countable = source ~= 'kaggle' or (item.closes ~= nil and item.closes < today)
                if countable then
                    table_insert(alerts, {
                        kind = 'closed',
                        item_id = item.id,
                        title = item.title,
                        closes = item.closes,
                        reward = item.reward,
                    })
                end
            end
        end
    end
    return alerts
end

-- ---------------------------------------------------------------------
-- State file: defaults, validation, deterministic IO
-- ---------------------------------------------------------------------

--- The seeded watches, from the 2026-10-08 tooling survey: CDMRP via
--- assistance listing 12.420, keyword watches over Matt's research
--- areas, and Kaggle competition watches. No snapshots: the first
--- check records baselines.
---@return research.watchlist.Watch[]
function M.default_watches()
    return {
        {
            id = 'cdmrp-12420',
            source = 'grants',
            label = 'CDMRP (PRORP / PRMRP) - assistance listing 12.420',
            assistance_listing = '12.420',
            statuses = { 'forecasted', 'posted' },
        },
        {
            id = 'grants-ai-healthcare',
            source = 'grants',
            label = 'Grants.gov - artificial intelligence in healthcare',
            query = 'artificial intelligence healthcare',
            statuses = { 'forecasted', 'posted' },
        },
        {
            id = 'grants-medical-education',
            source = 'grants',
            label = 'Grants.gov - medical education',
            query = 'medical education',
            statuses = { 'forecasted', 'posted' },
        },
        {
            id = 'grants-orthopedic',
            source = 'grants',
            label = 'Grants.gov - orthopedic',
            query = 'orthopedic',
            statuses = { 'forecasted', 'posted' },
        },
        {
            id = 'kaggle-health',
            source = 'kaggle',
            label = 'Kaggle - health competitions',
            search = 'health',
            sort_by = 'recentlyCreated',
            category = 'all',
        },
        {
            id = 'kaggle-recent',
            source = 'kaggle',
            label = 'Kaggle - newest competitions',
            search = '',
            sort_by = 'recentlyCreated',
            category = 'all',
        },
    }
end

--- Validates one snapshot item from the state file.
---@param raw any
---@return research.watchlist.Item|nil
local function state_item(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    local id = optional_string(raw, 'id')
    local title = optional_string(raw, 'title')
    if id == nil or title == nil then
        return nil
    end
    return {
        id = id,
        title = title,
        closes = date_prefix(optional_string(raw, 'closes')),
        reward = optional_string(raw, 'reward'),
        category = optional_string(raw, 'category'),
        status = optional_string(raw, 'status'),
        detail = optional_string(raw, 'detail'),
    }
end

--- Narrows a raw source value to a known watch source, or nil.
---@param value string|nil
---@return string|nil
local function watch_source(value)
    if value == 'grants' or value == 'kaggle' then
        return value
    end
    return nil
end

--- Validates one watch entry from the state file. A grants watch must
--- name a query or an assistance listing: an unfiltered Grants.gov
--- search is a firehose, not a watch.
---@param raw any
---@param seen_ids table<string, boolean>
---@return research.watchlist.Watch|nil watch
---@return research.watchlist.Error|nil err
local function state_watch(raw, seen_ids)
    if type(raw) ~= 'table' then
        return nil, make_error('invalid_state', 'watch entry is not an object', nil)
    end
    local id = optional_string(raw, 'id')
    local source = watch_source(optional_string(raw, 'source'))
    if id == nil then
        return nil, make_error('invalid_state', 'watch entry lacks a valid id', nil)
    end
    if source == nil then
        return nil, make_error('invalid_state', 'watch entry lacks a valid source', nil)
    end
    if seen_ids[id] then
        return nil, make_error('invalid_state', 'duplicate watch id in state file: ' .. id, nil)
    end
    seen_ids[id] = true
    ---@type research.watchlist.Watch
    local watch = {
        id = id,
        source = source,
        label = optional_string(raw, 'label') or id,
        query = optional_string(raw, 'query'),
        query_operator = optional_string(raw, 'query_operator'),
        assistance_listing = optional_string(raw, 'assistance_listing'),
        search = optional_string(raw, 'search'),
        sort_by = optional_string(raw, 'sort_by'),
        category = optional_string(raw, 'category'),
    }
    if source == 'grants' and watch.query == nil and watch.assistance_listing == nil then
        return nil,
            make_error(
                'invalid_state',
                'grants watch ' .. id .. ' names neither a query nor an assistance listing',
                nil
            )
    end
    if raw.statuses ~= nil then
        if not is_array(raw.statuses) then
            return nil, make_error('invalid_state', 'watch ' .. id .. ' statuses is not a list', nil)
        end
        local statuses = {}
        for _, status in ipairs(raw.statuses) do
            if type(status) ~= 'string' then
                return nil, make_error('invalid_state', 'watch ' .. id .. ' has a non-string status', nil)
            end
            table_insert(statuses, status)
        end
        watch.statuses = statuses
    end
    if raw.snapshot ~= nil then
        if type(raw.snapshot) ~= 'table' or not is_array(raw.snapshot.items) then
            return nil, make_error('invalid_state', 'watch ' .. id .. ' snapshot is malformed', nil)
        end
        if #raw.snapshot.items > ITEMS_PER_WATCH_MAX then
            return nil, make_error('invalid_state', 'watch ' .. id .. ' snapshot exceeds the item cap', nil)
        end
        local items = {}
        for _, raw_item in ipairs(raw.snapshot.items) do
            local item = state_item(raw_item)
            if item == nil then
                return nil, make_error('invalid_state', 'watch ' .. id .. ' snapshot holds a malformed item', nil)
            end
            table_insert(items, item)
        end
        watch.snapshot = {
            checked_at = optional_string(raw.snapshot, 'checked_at') or '',
            items = items,
        }
    end
    return watch, nil
end

--- Loads and validates the state file. A missing file is a clean
--- first run: the default watches, in memory only.
---@return table|nil state
---@return research.watchlist.Error|nil err
function M.load_state()
    if fn.filereadable(config.state_path) ~= 1 then
        return { schema_version = STATE_SCHEMA_VERSION, watches = M.default_watches() }, nil
    end
    if fn.getfsize(config.state_path) > STATE_BYTES_MAX then
        return nil, make_error('invalid_state', 'watchlist state file exceeds the size cap', nil)
    end
    local lines = fn.readfile(config.state_path, '', STATE_BYTES_MAX)
    local ok, decoded = pcall(json_decode, table_concat(lines, '\n'))
    if not ok or type(decoded) ~= 'table' or is_array(decoded) then
        return nil, make_error('invalid_state', 'watchlist state file is not a JSON object', nil)
    end
    if decoded.schema_version ~= STATE_SCHEMA_VERSION then
        return nil, make_error('invalid_state', 'watchlist state file has an unsupported schema_version', nil)
    end
    if not is_array(decoded.watches) or #decoded.watches > WATCHES_MAX then
        return nil, make_error('invalid_state', 'watchlist state file watches list is malformed or over the cap', nil)
    end
    local seen_ids = {}
    local watches = {}
    for _, raw_watch in ipairs(decoded.watches) do
        local watch, err = state_watch(raw_watch, seen_ids)
        if watch == nil then
            return nil, err
        end
        table_insert(watches, watch)
    end
    return { schema_version = STATE_SCHEMA_VERSION, watches = watches }, nil
end

--- Serializes a JSON value deterministically: map keys sorted, so a
--- state file diff means something and re-saving an unchanged state
--- is byte-stable. Lists are tables with sequential integer keys.
---@param value any
---@return string
local function encode_json(value)
    local kind = type(value)
    if kind == 'string' or kind == 'number' or kind == 'boolean' then
        return json_encode(value)
    end
    assert(kind == 'table', 'state values must be JSON-shaped')
    if is_array(value) then
        local parts = {}
        for _, entry in ipairs(value) do
            table_insert(parts, encode_json(entry))
        end
        return '[' .. table_concat(parts, ',') .. ']'
    end
    local keys = {}
    for key in pairs(value) do
        table_insert(keys, key)
    end
    table_sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        table_insert(parts, json_encode(key) .. ':' .. encode_json(value[key]))
    end
    return '{' .. table_concat(parts, ',') .. '}'
end

--- Converts a watch to its state-file shape (nil fields simply omit).
---@param watch research.watchlist.Watch
---@return table
local function watch_to_state(watch)
    local out = {
        id = watch.id,
        source = watch.source,
        label = watch.label,
        query = watch.query,
        query_operator = watch.query_operator,
        assistance_listing = watch.assistance_listing,
        statuses = watch.statuses,
        search = watch.search,
        sort_by = watch.sort_by,
        category = watch.category,
    }
    if watch.snapshot ~= nil then
        out.snapshot = { checked_at = watch.snapshot.checked_at, items = watch.snapshot.items }
    end
    return out
end

--- Persists the state file atomically (temp file, then rename), so a
--- timer-driven reader never sees a half-written state.
---@param state table
---@return boolean|nil ok
---@return research.watchlist.Error|nil err
function M.save_state(state)
    assert(type(state) == 'table' and is_array(state.watches), 'state with a watches list is required')
    local watches = {}
    for _, watch in ipairs(state.watches) do
        table_insert(watches, watch_to_state(watch))
    end
    local encoded = encode_json({ schema_version = STATE_SCHEMA_VERSION, watches = watches })
    local directory = fn.fnamemodify(config.state_path, ':h')
    fn.mkdir(directory, 'p')
    local temp_path = config.state_path .. '.tmp'
    if fn.writefile({ encoded }, temp_path) ~= 0 then
        return nil, make_error('io', 'could not write watchlist state temp file', nil)
    end
    if fn.rename(temp_path, config.state_path) ~= 0 then
        return nil, make_error('io', 'could not move watchlist state file into place', nil)
    end
    return true, nil
end

-- ---------------------------------------------------------------------
-- Check cycle
-- ---------------------------------------------------------------------

--- Runs one watch: resolve its source credentials, fetch, diff.
--- Returns the per-watch result and, on success, the new snapshot.
---@param watch research.watchlist.Watch
---@param budget table
---@param today string
---@return research.watchlist.WatchResult result
---@return research.watchlist.Snapshot|nil snapshot
local function check_watch(watch, budget, today)
    local result = {
        id = watch.id,
        source = watch.source,
        label = watch.label,
        status = 'error',
        baseline = watch.snapshot == nil,
        items_found = 0,
        truncated = false,
        alerts = {},
    }
    local items, total, truncated, err
    if watch.source == 'grants' then
        local key, key_err = grants_api_key()
        if key == nil then
            result.error = key_err
            return result, nil
        end
        items, total, truncated, err = fetch_grants(watch, key, budget)
    else
        local credentials, cred_err = kaggle_credentials()
        if credentials == nil then
            result.error = cred_err
            return result, nil
        end
        items, total, truncated, err = fetch_kaggle(watch, credentials, budget)
    end
    if items == nil then
        result.error = err
        return result, nil
    end
    local previous = nil
    if watch.snapshot ~= nil then
        previous = watch.snapshot.items
    end
    local alerts = diff_items(watch.source, previous, items, truncated, today)
    for _, alert in ipairs(alerts) do
        alert.watch_id = watch.id
        alert.source = watch.source
    end
    result.status = 'ok'
    result.items_found = #items
    result.total = total
    result.truncated = truncated
    result.alerts = alerts
    return result, { checked_at = utc_now(), items = items }
end

--- Runs a full check: every watch against its source, diffs against
--- the stored snapshots, persists the updated snapshots. A failed
--- watch keeps its old snapshot -- an error never erases state.
---@return research.watchlist.CheckResult|nil result
---@return research.watchlist.Error|nil err
function M.check()
    local state, load_err = M.load_state()
    if state == nil then
        return nil, load_err
    end
    local budget = { remaining = REQUESTS_PER_CHECK_MAX }
    local today = utc_today()
    local result = {
        checked_at = utc_now(),
        saved = false,
        watches = {},
        alerts = {},
        errors = {},
    }
    local state_changed = false
    for _, watch in ipairs(state.watches) do
        local watch_result, snapshot = check_watch(watch, budget, today)
        table_insert(result.watches, watch_result)
        for _, alert in ipairs(watch_result.alerts) do
            table_insert(result.alerts, alert)
        end
        if watch_result.error ~= nil then
            table_insert(result.errors, watch_result.error)
        end
        if snapshot ~= nil then
            watch.snapshot = snapshot
            state_changed = true
        end
    end
    if state_changed then
        local saved, save_err = M.save_state(state)
        if saved then
            result.saved = true
        elseif save_err ~= nil then
            table_insert(result.errors, save_err)
        end
    end
    return result, nil
end

-- ---------------------------------------------------------------------
-- Display
-- ---------------------------------------------------------------------

--- Renders one alert as a single display line.
---@param alert research.watchlist.Alert
---@return string
local function format_alert(alert)
    local when = alert.closes ~= nil and ('closes ' .. alert.closes) or 'no close date'
    if alert.kind == 'new' then
        local reward = alert.reward ~= nil and (' - reward ' .. alert.reward) or ''
        return string_format('NEW    [%s] %s (%s%s)', alert.watch_id, alert.title, when, reward)
    elseif alert.kind == 'date_changed' then
        local was = alert.previous_closes ~= nil and alert.previous_closes or 'none announced'
        return string_format('DATE   [%s] %s (%s -> %s)', alert.watch_id, alert.title, was, when)
    elseif alert.kind == 'reward_changed' then
        local was = alert.previous_reward ~= nil and alert.previous_reward or 'none'
        local now = alert.reward ~= nil and alert.reward or 'none'
        return string_format('REWARD [%s] %s (%s -> %s)', alert.watch_id, alert.title, was, now)
    end
    return string_format('CLOSED [%s] %s (was %s)', alert.watch_id, alert.title, when)
end

--- Display lines for a check result: summary, per-watch outcomes,
--- then every alert. Used by :WatchlistCheck and check_and_print().
---@param result research.watchlist.CheckResult
---@return string[]
function M.format_check(result)
    assert(type(result) == 'table' and is_array(result.watches), 'a check result is required')
    local ok_count = 0
    for _, watch_result in ipairs(result.watches) do
        if watch_result.status == 'ok' then
            ok_count = ok_count + 1
        end
    end
    local lines = {
        string_format(
            'Watchlist check %s - %d/%d watches ok, %d alerts, %d errors%s',
            result.checked_at,
            ok_count,
            #result.watches,
            #result.alerts,
            #result.errors,
            result.saved and '' or ' (state NOT saved)'
        ),
    }
    for _, watch_result in ipairs(result.watches) do
        if watch_result.status == 'ok' then
            local total = watch_result.total ~= nil and (' of ' .. tostring(watch_result.total)) or ''
            local note = watch_result.baseline and ' - baseline recorded' or ''
            if watch_result.truncated then
                note = note .. ' - TRUNCATED at cap'
            end
            table_insert(
                lines,
                string_format(
                    '  [%s] %s - %d items%s%s',
                    watch_result.source,
                    watch_result.id,
                    watch_result.items_found,
                    total,
                    note
                )
            )
        else
            local watch_err = watch_result.error or { code = 'unknown', message = 'no error detail recorded' }
            table_insert(
                lines,
                string_format(
                    '  [%s] %s - ERROR %s: %s',
                    watch_result.source,
                    watch_result.id,
                    watch_err.code,
                    watch_err.message
                )
            )
        end
    end
    for _, alert in ipairs(result.alerts) do
        table_insert(lines, format_alert(alert))
    end
    return lines
end

--- Display lines for the watched entries and their last state.
---@param state table
---@return string[]
function M.format_watchlist(state)
    assert(type(state) == 'table' and is_array(state.watches), 'a watchlist state is required')
    local lines = { 'Research watchlist (' .. config.state_path .. ')' }
    for _, watch in ipairs(state.watches) do
        table_insert(lines, string_format('[%s] %s - %s', watch.source, watch.id, watch.label))
        if watch.snapshot == nil then
            table_insert(lines, '  never checked')
        else
            table_insert(
                lines,
                string_format('  last check %s - %d items', watch.snapshot.checked_at, #watch.snapshot.items)
            )
            for index, item in ipairs(watch.snapshot.items) do
                if index > ITEMS_DISPLAY_MAX then
                    table_insert(lines, '  ... and ' .. tostring(#watch.snapshot.items - ITEMS_DISPLAY_MAX) .. ' more')
                    break
                end
                local closes = item.closes ~= nil and (' - closes ' .. item.closes) or ''
                local reward = item.reward ~= nil and (' - reward ' .. item.reward) or ''
                table_insert(lines, '  - ' .. item.title .. closes .. reward)
            end
        end
    end
    return lines
end

--- Shows lines in the house scratch-buffer viewer (read-only,
--- non-listed, q to close), matching the other research modules.
---@param lines string[]
---@param name string
---@return integer bufnr
local function show_lines(lines, name)
    assert(type(lines) == 'table', 'display lines are required')
    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(bufnr, name)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
    api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
    api.nvim_win_set_buf(0, bufnr)
    api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
    return bufnr
end

--- Reports an error through a scheduled notification: a bare
--- vim.notify at ERROR level throws for RPC/headless callers.
---@param err research.watchlist.Error|nil
local function notify_error(err)
    assert(type(err) == 'table' and type(err.message) == 'string', 'a structured error is required')
    vim.schedule(function()
        vim.notify(err.message, vim.log.levels.ERROR)
    end)
end

--- :ResearchWatchlist -- show the watched entries and last state.
local function cmd_show()
    local state, err = M.load_state()
    if state == nil then
        notify_error(err)
        return
    end
    show_lines(M.format_watchlist(state), 'diver://research-watchlist')
end

--- :WatchlistCheck -- run a check now, notify alerts, show the summary.
local function cmd_check()
    local result, err = M.check()
    if result == nil then
        notify_error(err)
        return
    end
    for index, alert in ipairs(result.alerts) do
        if index > ALERTS_NOTIFY_MAX then
            vim.schedule(function()
                vim.notify(
                    'watchlist: ... and '
                        .. tostring(#result.alerts - ALERTS_NOTIFY_MAX)
                        .. ' more alerts (see :WatchlistCheck summary)',
                    vim.log.levels.WARN
                )
            end)
            break
        end
        local line = format_alert(alert)
        vim.schedule(function()
            vim.notify('watchlist: ' .. line, vim.log.levels.WARN)
        end)
    end
    if #result.alerts == 0 and #result.errors == 0 then
        vim.schedule(function()
            vim.notify('watchlist: no changes across ' .. tostring(#result.watches) .. ' watches', vim.log.levels.INFO)
        end)
    end
    for _, watch_err in ipairs(result.errors) do
        notify_error(watch_err)
    end
    show_lines(M.format_check(result), 'diver://research-watchlist-check')
end

--- Headless entry point: runs a check and prints the formatted
--- result, one line per print, so `nvim --headless` invocations (a
--- future timer or cron) surface alerts on stdout.
---@return research.watchlist.CheckResult|nil result
---@return research.watchlist.Error|nil err
function M.check_and_print()
    local result, err = M.check()
    if result == nil then
        local message = err ~= nil and err.message or 'unknown error'
        print('watchlist check failed: ' .. message)
        return nil, err
    end
    for _, line in ipairs(M.format_check(result)) do
        print(line)
    end
    return result, nil
end

-- ---------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------

--- Applies configuration overrides and registers the user commands.
--- Transport and credential seams exist for the shared research test
--- suite; production callers use the defaults.
---@param opts table|nil
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'setup options must be a table')
    if opts.api_base_grants ~= nil then
        assert(type(opts.api_base_grants) == 'string', 'api_base_grants must be a string')
        config.api_base_grants = opts.api_base_grants
    end
    if opts.api_base_kaggle ~= nil then
        assert(type(opts.api_base_kaggle) == 'string', 'api_base_kaggle must be a string')
        config.api_base_kaggle = opts.api_base_kaggle
    end
    if opts.grants_api_key ~= nil then
        assert(type(opts.grants_api_key) == 'string', 'grants_api_key must be a string')
        config.grants_api_key = opts.grants_api_key
    end
    if opts.kaggle_key ~= nil then
        assert(type(opts.kaggle_key) == 'string', 'kaggle_key must be a string')
        config.kaggle_key = opts.kaggle_key
    end
    if opts.kaggle_username ~= nil then
        assert(type(opts.kaggle_username) == 'string', 'kaggle_username must be a string')
        config.kaggle_username = opts.kaggle_username
    end
    if opts.kaggle_config_path ~= nil then
        assert(type(opts.kaggle_config_path) == 'string', 'kaggle_config_path must be a string')
        config.kaggle_config_path = opts.kaggle_config_path
    end
    if opts.secret_field_grants ~= nil then
        assert(type(opts.secret_field_grants) == 'string', 'secret_field_grants must be a string')
        config.secret_field_grants = opts.secret_field_grants
    end
    if opts.secret_field_kaggle_key ~= nil then
        assert(type(opts.secret_field_kaggle_key) == 'string', 'secret_field_kaggle_key must be a string')
        config.secret_field_kaggle_key = opts.secret_field_kaggle_key
    end
    if opts.secret_field_kaggle_username ~= nil then
        assert(type(opts.secret_field_kaggle_username) == 'string', 'secret_field_kaggle_username must be a string')
        config.secret_field_kaggle_username = opts.secret_field_kaggle_username
    end
    if opts.secret_tier_program ~= nil then
        assert(type(opts.secret_tier_program) == 'string', 'secret_tier_program must be a string')
        config.secret_tier_program = opts.secret_tier_program
    end
    if opts.state_path ~= nil then
        assert(type(opts.state_path) == 'string', 'state_path must be a string')
        config.state_path = opts.state_path
    end
    if opts.transport ~= nil then
        assert(type(opts.transport) == 'function', 'transport must be a function')
        config.transport = opts.transport
    end
    pcall(api.nvim_create_user_command, 'ResearchWatchlist', cmd_show, {
        desc = 'Show the research watchlist and its last-seen state',
    })
    pcall(api.nvim_create_user_command, 'WatchlistCheck', cmd_check, {
        desc = 'Run a research watchlist check now',
    })
end

return M
