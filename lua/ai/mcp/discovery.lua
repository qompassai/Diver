-- /qompassai/Diver/lua/ai/mcp/discovery.lua
-- Qompass AI MCP Server Discovery (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Find MCP servers worth installing and register them after explicit
-- user confirmation. Two search backends:
--
--   PRIMARY: Matt's SearXNG module (config.nav.searxng). That module only
--   exposes M.parse for turning a response body into results -- it has no
--   programmatic search entry point -- so this module runs its own bounded
--   curl POST that mirrors searxng.lua's argv pattern (--data-urlencode,
--   --max-filesize, timeouts) and reuses M.parse on the body.
--
--   FALLBACK: Brave Search API (https://api.search.brave.com/res/v1/web/
--   search, header X-Subscription-Token: $BRAVE_API_KEY). Used ONLY when
--   SEARXNG_URL is unset. NOTE: there is no brave module in the diver
--   repo, so this is a minimal native client written here. It has not been
--   exercised end-to-end (no API key in this environment); treat it as
--   untested until someone runs it with a key.
--
-- Installing from a result writes a registry entry ONLY after the user
-- confirms the full command/argv by typing the server name. Entries using
-- npx/uvx/bunx-style auto-fetchers, remote URLs, or shell wrappers raise
-- loud warnings first (see registry.risk_flags).

local registry = require('ai.mcp.registry')

local M = {}

local SEARCH_RESULTS_MAX = 20
local QUERY_LENGTH_MAX = 200
local CURL_TIMEOUT_MS = 25000
local BRAVE_ENDPOINT = 'https://api.search.brave.com/res/v1/web/search'

---@class McpSearchResult
---@field title string
---@field url string
---@field content string

---@param query any
---@return boolean
---@return string?
local function validate_query(query)
    if type(query) ~= 'string' or query == '' then
        return false, 'query must be a non-empty string'
    end
    if #query > QUERY_LENGTH_MAX then
        return false, 'query exceeds ' .. QUERY_LENGTH_MAX .. ' characters'
    end
    if query:find('%z') ~= nil then
        return false, 'query contains NUL'
    end
    return true, nil
end

---@return string? base URL, or nil when SearXNG is not configured
local function searxng_base()
    local url = vim.env.SEARXNG_URL
    if type(url) ~= 'string' or url == '' then
        return nil
    end
    if url:match('^https?://[^/]+$') == nil and url:match('^https?://[^/]+/') == nil then
        return nil
    end
    if url:find('[%c%s]') ~= nil then
        return nil
    end
    return url:gsub('/+$', '')
end

---@param stdout string
---@param callback fun(err: string?, results: McpSearchResult[]?)
local function parse_searxng(stdout, callback)
    local ok, searxng = pcall(require, 'config.nav.searxng')
    if not ok or type(searxng) ~= 'table' or type(searxng.parse) ~= 'function' then
        callback('config.nav.searxng is unavailable', nil)
        return
    end
    local results, parse_err = searxng.parse(stdout)
    if results == nil then
        callback('SearXNG parse failed: ' .. tostring(parse_err), nil)
        return
    end
    local trimmed = {}
    for index, item in ipairs(results) do
        if index > SEARCH_RESULTS_MAX then
            break
        end
        trimmed[#trimmed + 1] = { title = item.title, url = item.url, content = item.content }
    end
    callback(nil, trimmed)
end

---@param base string
---@param query string
---@param callback fun(err: string?, results: McpSearchResult[]?)
local function search_searxng(base, query, callback)
    -- Mirrors config.nav.searxng's argv: -q first to ignore curlrc, POST
    -- keeps the query out of the URL, bounded time and response size.
    local argv = {
        'curl',
        '-q',
        '--silent',
        '--show-error',
        '--fail',
        '--proto',
        '=http,https',
        '--connect-timeout',
        '5',
        '--max-time',
        '20',
        '--max-filesize',
        '2097152',
        '--data-urlencode',
        'format=json',
        '--data-urlencode',
        'q=' .. query .. ' MCP server',
        '--data-urlencode',
        'pageno=1',
        '--url',
        base .. '/search',
    }
    local result = vim.system(argv, { text = true, timeout = CURL_TIMEOUT_MS }):wait()
    if result.code ~= 0 then
        callback('SearXNG request failed: ' .. (result.stderr or ''):sub(1, 200), nil)
        return
    end
    parse_searxng(result.stdout or '', callback)
end

---@param key string
---@param query string
---@param callback fun(err: string?, results: McpSearchResult[]?)
local function search_brave(key, query, callback)
    local argv = {
        'curl',
        '-q',
        '--silent',
        '--show-error',
        '--fail',
        '--proto',
        '=https',
        '--connect-timeout',
        '5',
        '--max-time',
        '20',
        '--max-filesize',
        '2097152',
        '--get',
        '--data-urlencode',
        'q=' .. query .. ' MCP server',
        '--data-urlencode',
        'count=' .. SEARCH_RESULTS_MAX,
        '--header',
        'X-Subscription-Token: ' .. key,
        '--url',
        BRAVE_ENDPOINT,
    }
    local result = vim.system(argv, { text = true, timeout = CURL_TIMEOUT_MS }):wait()
    if result.code ~= 0 then
        callback('Brave request failed: ' .. (result.stderr or ''):sub(1, 200), nil)
        return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok or type(decoded) ~= 'table' then
        callback('Brave returned invalid JSON', nil)
        return
    end
    local web = decoded.web
    if type(web) ~= 'table' or type(web.results) ~= 'table' then
        callback('Brave returned no web results', nil)
        return
    end
    local results = {}
    for index, item in ipairs(web.results) do
        if index > SEARCH_RESULTS_MAX then
            break
        end
        if type(item) == 'table' and type(item.url) == 'string' and item.url ~= '' then
            results[#results + 1] = {
                title = type(item.title) == 'string' and item.title:sub(1, 200) or '',
                url = item.url,
                content = type(item.description) == 'string' and item.description:sub(1, 500) or '',
            }
        end
    end
    callback(nil, results)
end

---@param query string
---@param callback fun(err: string?, results: McpSearchResult[]?)
function M.search(query, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local valid, validation_err = validate_query(query)
    if not valid then
        callback(validation_err, nil)
        return
    end
    assert(validation_err == nil, 'validate_query returned false with no error')
    if vim.fn.executable('curl') ~= 1 then
        callback('curl is not installed', nil)
        return
    end
    local base = searxng_base()
    if base ~= nil then
        search_searxng(base, query, callback)
        return
    end
    local key = vim.env.BRAVE_API_KEY
    if type(key) == 'string' and key ~= '' then
        search_brave(key, query, callback)
        return
    end
    callback('no search backend: set SEARXNG_URL or BRAVE_API_KEY', nil)
end

---@param result McpSearchResult
function M.install_from_result(result)
    assert(type(result) == 'table', 'result must be a table')
    vim.ui.input({ prompt = 'Server name: ' }, function(name)
        if name == nil or name == '' then
            return
        end
        vim.ui.input({ prompt = 'Command (absolute path to executable): ' }, function(command)
            if command == nil or command == '' then
                return
            end
            vim.ui.input({ prompt = 'Args (JSON array): ', default = '[]' }, function(args_text)
                if args_text == nil then
                    return
                end
                local ok, args = pcall(vim.json.decode, args_text)
                if not ok or type(args) ~= 'table' then
                    vim.notify('Args must be a JSON array of strings', vim.log.levels.ERROR)
                    return
                end
                ---@type McpServerEntry
                local entry = { name = name, command = command, args = args, enabled = true }
                local valid, validation_err = registry.validate(entry)
                if not valid then
                    vim.notify('Invalid entry: ' .. tostring(validation_err), vim.log.levels.ERROR)
                    return
                end
                local flags = registry.risk_flags(entry)
                local preview = 'Install MCP server from:\n  '
                    .. result.title
                    .. '\n  '
                    .. result.url
                    .. '\n\nname:    '
                    .. name
                    .. '\ncommand: '
                    .. command
                    .. '\nargs:    '
                    .. vim.json.encode(args)
                for _, flag in ipairs(flags) do
                    preview = preview .. '\nWARNING: ' .. flag
                end
                if #flags > 0 then
                    vim.notify(preview, vim.log.levels.WARN)
                end
                local confirm_prompt = 'Type the server name to confirm install: '
                vim.ui.input({ prompt = confirm_prompt }, function(typed)
                    if typed ~= name then
                        vim.notify('Install cancelled: name mismatch', vim.log.levels.WARN)
                        return
                    end
                    local added, add_err = registry.add(entry)
                    if not added then
                        vim.notify('Install failed: ' .. tostring(add_err), vim.log.levels.ERROR)
                        return
                    end
                    vim.notify('MCP server installed: ' .. name, vim.log.levels.INFO)
                end)
            end)
        end)
    end)
end

---@param query string
function M.install_menu(query)
    M.search(query, function(err, results)
        vim.schedule(function()
            if err ~= nil then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            assert(results ~= nil, 'search returned no error and no results')
            if #results == 0 then
                vim.notify('No MCP servers found for: ' .. query, vim.log.levels.WARN)
                return
            end
            vim.ui.select(results, {
                prompt = 'Install MCP server:',
                format_item = function(item)
                    return item.title .. ' — ' .. item.url
                end,
            }, function(item)
                if item ~= nil then
                    M.install_from_result(item)
                end
            end)
        end)
    end)
end

---@param query string
function M.search_menu(query)
    M.search(query, function(err, results)
        vim.schedule(function()
            if err ~= nil then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            assert(results ~= nil, 'search returned no error and no results')
            if #results == 0 then
                vim.notify('No MCP servers found for: ' .. query, vim.log.levels.WARN)
                return
            end
            vim.ui.select(results, {
                prompt = 'MCP servers for "' .. query .. '":',
                format_item = function(item)
                    return item.title .. ' — ' .. item.url
                end,
            }, function(item)
                if item == nil then
                    return
                end
                vim.ui.select({ 'Install this server', 'Open URL', 'Cancel' }, {
                    prompt = item.title,
                }, function(choice)
                    if choice == 'Install this server' then
                        M.install_from_result(item)
                    elseif choice == 'Open URL' then
                        local _, open_err = vim.ui.open(item.url)
                        if open_err then
                            vim.notify(tostring(open_err), vim.log.levels.ERROR)
                        end
                    end
                end)
            end)
        end)
    end)
end

return M
