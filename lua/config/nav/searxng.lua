-- /qompassai/Diver/lua/config/nav/searxng.lua
-- Explicit queries to a configured SearXNG instance; bounded JSON, native result picker.
-- SPDX-License-Identifier: Apache-2.0
local async = require('config.core.async')
local M = {}
local options = {}
local generation, process, last = 0, nil, nil

---@param text string
local function notify(text)
    vim.notify(text, vim.log.levels.WARN, { title = 'SearXNG' })
end

local function http_url(url)
    return type(url) == 'string'
        and #url <= 8192
        and url:match('^https?://[^/]+') ~= nil
        and not url:find('[%c%s]')
        and not url:match('^https?://[^/]*@')
end

local function clean(text)
    return (tostring(text or ''):sub(1, 2048):gsub('[%c]', ' '))
end

---Parse a SearXNG JSON response into picker results.
---
---Plain-language version: takes the raw text the search server sent back and
---turns each result into an entry the picker can show.
---@param body string Raw HTTP response body from the SearXNG instance.
---@return table[]?, string?
function M.parse(body)
    if type(body) ~= 'string' or #body > 2 * 1024 * 1024 then
        return nil, 'Invalid response size'
    end
    local ok, value = pcall(vim.json.decode, body)
    if not ok or type(value) ~= 'table' or type(value.results) ~= 'table' then
        return nil, 'Instance did not return a JSON results array; enable search.formats: [html, json]'
    end
    local results = {}
    for index = 1, math.min(#value.results, 200) do
        local entry = value.results[index]
        if type(entry) == 'table' and http_url(entry.url) then
            results[#results + 1] = {
                title = clean(entry.title),
                url = entry.url,
                content = clean(entry.content),
                engine = clean(entry.engine),
            }
        end
    end
    return results
end

function M.results()
    if not last or #last.results == 0 then
        notify('No search results')
        return
    end
    local saved = last
    vim.ui.select(saved.results, {
        prompt = ('SearXNG: %s (page %d)'):format(clean(saved.query), saved.page),
        format_item = function(item)
            return item.title .. ' — ' .. item.url
        end,
    }, function(item)
        if not item or last ~= saved then
            return
        end
        local _, err = vim.ui.open(item.url)
        if err then
            notify(tostring(err))
        end
    end)
end

function M.cancel()
    generation = generation + 1
    if process then
        local ok, err = pcall(process.kill, process, 9)
        if not ok then
            notify('Cancel: ' .. tostring(err))
        end
        process = nil
    end
end

---@param query? string
---@param page? integer
function M.search(query, page)
    local instance = options.url or vim.env.SEARXNG_URL
    if not http_url(instance) or instance:find('[?#]') then
        notify('Set SEARXNG_URL or navmap.searxng.url to your instance base URL')
        return
    end
    if vim.fn.executable('curl') ~= 1 then
        notify('Install curl for SearXNG requests')
        return
    end
    page = page or 1
    assert(type(page) == 'number' and page % 1 == 0 and page >= 1 and page <= 100)
    M.cancel()
    local token = generation
    local function run(value)
        if token ~= generation or value == nil or value == '' then
            return
        end
        if type(value) ~= 'string' or #value > 4096 or value:find('%z') then
            notify('Invalid query')
            return
        end
        -- -q is first to ignore curlrc; POST keeps the query out of the URL.
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
            'q=' .. value,
            '--data-urlencode',
            'pageno=' .. page,
        }
        for _, key in ipairs({ 'categories', 'engines', 'language', 'safesearch', 'time_range' }) do
            if options[key] ~= nil then
                vim.list_extend(argv, { '--data-urlencode', key .. '=' .. tostring(options[key]) })
            end
        end
        vim.list_extend(argv, { '--url', instance:gsub('/+$', '') .. '/search' })
        local err
        process, err = async.spawn(argv, { timeout = 22000, max_output_bytes = 2 * 1024 * 1024 }, function(result)
            if token ~= generation then
                return
            end
            process = nil
            if result.code ~= 0 or result.error then
                notify(result.error or clean(result.stderr) .. ' (JSON may be disabled on the instance)')
                return
            end
            local results, parse_error = M.parse(result.stdout)
            if not results then
                assert(parse_error ~= nil, 'M.parse returned no results and no error')
                notify(parse_error)
                return
            end
            last = { query = value, page = page, results = results }
            M.results()
        end)
        if err then
            notify(err)
        end
    end
    if query == nil then
        vim.ui.input({ prompt = 'SearXNG query: ' }, run)
    else
        run(query)
    end
end

function M.next_page()
    if not last then
        notify('Search first')
        return
    end
    if last.page >= 100 then
        notify('Page limit reached')
        return
    end
    M.search(last.query, last.page + 1)
end

function M.setup(opts)
    assert(opts == nil or type(opts) == 'table')
    local candidate = vim.deepcopy(opts or {})
    if candidate.url ~= nil then
        assert(http_url(candidate.url), 'Invalid SearXNG URL')
    end
    for _, key in ipairs({ 'categories', 'engines', 'language', 'safesearch', 'time_range' }) do
        local value = candidate[key]
        assert(
            value == nil
                or (type(value) == 'string' or type(value) == 'number')
                    and #tostring(value) <= 1024
                    and not tostring(value):find('%z'),
            'Invalid ' .. key
        )
    end
    M.cancel()
    options, last = candidate, nil
end
return M
