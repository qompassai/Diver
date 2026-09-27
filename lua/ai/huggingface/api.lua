-- /qompassai/Diver/lua/ai/huggingface/api.lua
-- Qompass AI Diver Hugging Face Hub API Client (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Bounded, dependency-free client for the public Hugging Face Hub REST
-- API. Endpoints verified live 2026-09-27 against
-- https://huggingface.co/docs/hub/api and the OpenAPI playground
-- (https://huggingface.co/.well-known/openapi.json):
--   GET {base}/api/models?search=&limit=     (list; carries NO description
--                                            field and NO license field --
--                                            license lives in tags as
--                                            'license:<spdx>')
--   GET {base}/api/models/{id}               (detail: lastModified, sha,
--                                            tags, pipeline_tag)
--   GET {base}/api/datasets?search=&limit=   (list carries description)
--   GET {base}/api/papers/search?q=&limit=   (hybrid semantic + full-text;
--                                            each hit is wrapped as
--                                            {paper = {...}}; q max 250
--                                            chars, limit 1..120)
--   GET {base}/api/models/{ns}/{repo}/xet-read-token/{rev}
--     (public for public repos; HTTP 200 with a casUrl field means the
--     repo is Xet-enabled. The minted accessToken is NEVER stored or
--     logged -- only the presence of casUrl is reported.)
-- Every request goes through security.rce.safe_exec in argv form with a
-- wall-clock cap and a body-size cap. Parsers are pure: truncated JSON,
-- Hub error shapes, and oversized input all yield an empty list, never
-- an error. Requiring this module performs no I/O and spawns nothing.
---@module 'ai.huggingface.api'

local M = {}

local rce = require('security.rce')

local BODY_BYTES_MAX = 262144 -- 256 KiB cap on any API response body.
local ENTRIES_MAX = 200 -- hard cap on parsed entries per response.
local TAGS_SHOWN_MAX = 8 -- tags shown per picker line.
local TEXT_CHARS_MAX = 2000 -- description/summary chars kept per entry.
local XET_PROBE_TIMEOUT_S = 10 -- wall-clock cap for the xet-read-token probe.

---@class ai.huggingface.ModelEntry
---@field id string Repo id, e.g. 'google-bert/bert-base-uncased'.
---@field likes integer
---@field downloads integer
---@field tags string[]
---@field pipeline_tag string|nil

---@class ai.huggingface.ModelDetail
---@field id string
---@field author string|nil
---@field likes integer
---@field downloads integer
---@field tags string[]
---@field pipeline_tag string|nil
---@field license string|nil SPDX id from the 'license:' tag.
---@field last_modified string|nil ISO-8601 timestamp.
---@field sha string|nil Full commit sha.
---@field gated boolean
---@field private boolean

---@class ai.huggingface.DatasetEntry
---@field id string
---@field author string|nil
---@field likes integer
---@field downloads integer
---@field tags string[]
---@field last_modified string|nil ISO-8601 timestamp.
---@field description string|nil

---@class ai.huggingface.PaperEntry
---@field id string arXiv id, e.g. '1706.03762'.
---@field title string
---@field summary string|nil
---@field authors string[]
---@field published_at string|nil ISO-8601 timestamp.

---@class ai.huggingface.XetProbe
---@field xet_enabled boolean True when the Hub minted a CAS-backed token.
---@field cas_url string|nil CAS server URL when xet_enabled.
---@field note string One-line human summary (never contains a token).

---Encode query params deterministically: keys sorted, values URI-encoded.
---@param params table<string,string|number>
---@return string query e.g. 'limit=20&search=bert'
function M.encode_params(params)
    local keys = {}
    for key, _ in pairs(params) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. '=' .. vim.uri_encode(tostring(params[key]))
    end
    return table.concat(parts, '&')
end

---Decode a JSON body expected to be an array. Anything else -- truncated
---JSON, a Hub error shape like {error=...}, a scalar -- yields {}.
---@param text string|nil Raw response body.
---@return table[] items Decoded array, capped at ENTRIES_MAX.
local function decode_list(text)
    if type(text) ~= 'string' or #text == 0 or #text > BODY_BYTES_MAX then
        return {}
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end
    -- A Hub error shape ({error=...}) or any non-array decodes to a table
    -- with no integer keys; treat it as "no results", not a failure.
    if decoded[1] == nil then
        return {}
    end
    local items = {}
    for index = 1, math.min(#decoded, ENTRIES_MAX) do
        if type(decoded[index]) == 'table' then
            items[#items + 1] = decoded[index]
        end
    end
    return items
end

---@param entry table Decoded JSON object.
---@param key string Field name.
---@return string|nil value
local function take_string(entry, key)
    local value = entry[key]
    if type(value) ~= 'string' or value == '' then
        return nil
    end
    return value
end

---@param entry table Decoded JSON object.
---@param key string Field name.
---@return integer value 0 when absent or non-numeric.
local function take_count(entry, key)
    local value = tonumber(entry[key])
    if value == nil or value < 0 then
        return 0
    end
    return math.floor(value)
end

---@param entry table Decoded JSON object.
---@param key string Field name.
---@return string[] values String elements only, in order.
local function take_string_list(entry, key)
    local raw = entry[key]
    local values = {}
    if type(raw) ~= 'table' then
        return values
    end
    for _, value in ipairs(raw) do
        if type(value) == 'string' and value ~= '' then
            values[#values + 1] = value
        end
    end
    return values
end

---Truncate long free text for display; nil stays nil.
---@param text string|nil
---@return string|nil
local function take_text(text)
    if type(text) ~= 'string' or text == '' then
        return nil
    end
    local trimmed = vim.trim(text)
    if #trimmed > TEXT_CHARS_MAX then
        return trimmed:sub(1, TEXT_CHARS_MAX) .. '...'
    end
    return trimmed
end

---SPDX license id from a 'license:<id>' tag, e.g. 'license:apache-2.0'.
---Nil when no license tag is present (the Hub genuinely omits it then).
---@param tags string[]
---@return string|nil license
function M.license_of(tags)
    for _, tag in ipairs(tags) do
        local license = tag:match('^license:(.+)$')
        if license ~= nil and license ~= '' then
            return license
        end
    end
    return nil
end

---Parse a /api/models list response. Pure: garbage in yields {}, never
---an error.
---@param text string|nil Raw response body.
---@return ai.huggingface.ModelEntry[] entries
function M.parse_models(text)
    local entries = {}
    for _, item in ipairs(decode_list(text)) do
        local id = take_string(item, 'id')
        if id ~= nil then
            entries[#entries + 1] = {
                id = id,
                likes = take_count(item, 'likes'),
                downloads = take_count(item, 'downloads'),
                tags = take_string_list(item, 'tags'),
                pipeline_tag = take_string(item, 'pipeline_tag'),
            }
        end
    end
    return entries
end

---Parse a /api/models/{id} detail response. Pure: garbage in yields nil.
---@param text string|nil Raw response body.
---@return ai.huggingface.ModelDetail|nil detail
function M.parse_model_detail(text)
    if type(text) ~= 'string' or #text == 0 or #text > BODY_BYTES_MAX then
        return nil
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil
    end
    local id = take_string(decoded, 'id')
    if id == nil then
        return nil
    end
    local tags = take_string_list(decoded, 'tags')
    return {
        id = id,
        author = take_string(decoded, 'author'),
        likes = take_count(decoded, 'likes'),
        downloads = take_count(decoded, 'downloads'),
        tags = tags,
        pipeline_tag = take_string(decoded, 'pipeline_tag'),
        license = M.license_of(tags),
        last_modified = take_string(decoded, 'lastModified'),
        sha = take_string(decoded, 'sha'),
        gated = decoded.gated == true,
        private = decoded.private == true,
    }
end

---Parse a /api/datasets list response. Pure: garbage in yields {}.
---@param text string|nil Raw response body.
---@return ai.huggingface.DatasetEntry[] entries
function M.parse_datasets(text)
    local entries = {}
    for _, item in ipairs(decode_list(text)) do
        local id = take_string(item, 'id')
        if id ~= nil then
            entries[#entries + 1] = {
                id = id,
                author = take_string(item, 'author'),
                likes = take_count(item, 'likes'),
                downloads = take_count(item, 'downloads'),
                tags = take_string_list(item, 'tags'),
                last_modified = take_string(item, 'lastModified'),
                description = take_text(item.description),
            }
        end
    end
    return entries
end

---Parse a /api/papers/search response. Each hit is wrapped as
---{paper = {...}}; a bare (unwrapped) object is accepted defensively.
---Pure: garbage in yields {}.
---@param text string|nil Raw response body.
---@return ai.huggingface.PaperEntry[] entries
function M.parse_papers(text)
    local entries = {}
    for _, item in ipairs(decode_list(text)) do
        local paper = item.paper
        if type(paper) ~= 'table' then
            paper = item
        end
        local id = take_string(paper, 'id')
        local title = take_string(paper, 'title')
        if id ~= nil and title ~= nil then
            local authors = {}
            for _, author in ipairs(take_string_list(paper, 'authors')) do
                authors[#authors + 1] = author
            end
            local raw_authors = paper.authors
            if type(raw_authors) == 'table' and #authors == 0 then
                -- Authors arrive as objects ({name=...}); extract names.
                for _, author in ipairs(raw_authors) do
                    if type(author) == 'table' then
                        local name = take_string(author, 'name')
                        if name ~= nil then
                            authors[#authors + 1] = name
                        end
                    end
                end
            end
            entries[#entries + 1] = {
                id = id,
                title = title,
                summary = take_text(paper.summary),
                authors = authors,
                published_at = take_string(paper, 'publishedAt'),
            }
        end
    end
    return entries
end

---Bounded HTTP GET via curl (argv form only). Returns the body plus the
---HTTP status code; network failures and non-2xx codes are reported as
---nil + reason, never thrown.
---@param url string Fully-formed URL (query already encoded).
---@param timeout_s integer Wall-clock cap for curl.
---@param extra_argv? string[] Extra curl words, e.g. { '-w', '\n%{http_code}' }.
---@return string|nil body
---@return integer|nil http_code
---@return string|nil err
function M.get(url, timeout_s, extra_argv)
    assert(type(url) == 'string' and url ~= '', 'api.get needs a non-empty URL')
    assert(type(timeout_s) == 'number' and timeout_s >= 1, 'api.get needs a positive timeout_s')
    local argv = {
        'curl',
        '-sS',
        '--max-time',
        tostring(math.floor(timeout_s)),
        '--max-filesize',
        tostring(BODY_BYTES_MAX),
    }
    for _, word in ipairs(extra_argv or {}) do
        argv[#argv + 1] = word
    end
    argv[#argv + 1] = url
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = (math.floor(timeout_s) + 5) * 1000 })
    if exec_err ~= nil then
        return nil, nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, nil, 'curl exited ' .. result.code .. ': ' .. vim.trim(result.stderr or '')
    end
    return result.stdout or '', result.code, nil
end

---Search the Hub. `kind` selects the verified endpoint; an empty query
---lists (the Hub's default ordering) instead of searching.
---@param kind 'models'|'datasets'|'papers'
---@param query string|nil Free-text query; nil/blank means "list".
---@param cfg table Live config: api_base, page_size, search_timeout_s, papers_endpoint.
---@return table[] entries Parsed entries (shape depends on kind).
---@return string|nil err
function M.search(kind, query, cfg)
    local path
    local param_key = 'search'
    if kind == 'models' then
        path = '/api/models'
    elseif kind == 'datasets' then
        path = '/api/datasets'
    elseif kind == 'papers' then
        path = cfg.papers_endpoint
        param_key = 'q'
    else
        return {}, 'unknown search kind: ' .. tostring(kind)
    end
    local params = { limit = math.max(1, math.min(cfg.page_size or 20, 100)) }
    local trimmed = vim.trim(query or '')
    if trimmed ~= '' then
        params[param_key] = trimmed
    end
    local url = cfg.api_base .. path .. '?' .. M.encode_params(params)
    local body, _, err = M.get(url, cfg.search_timeout_s or 15)
    if err ~= nil then
        return {}, err
    end
    if kind == 'models' then
        return M.parse_models(body)
    elseif kind == 'datasets' then
        return M.parse_datasets(body)
    else
        return M.parse_papers(body)
    end
end

---Fetch one model detail record. Pure network + parse; nil detail with
---nil err only when the record genuinely has no id field.
---@param repo_id string 'owner/name', validated by the caller.
---@param cfg table Live config: api_base, search_timeout_s.
---@return ai.huggingface.ModelDetail|nil detail
---@return string|nil err
function M.model_detail(repo_id, cfg)
    local url = cfg.api_base .. '/api/models/' .. repo_id
    local body, _, err = M.get(url, cfg.search_timeout_s or 15)
    if err ~= nil then
        return nil, err
    end
    local detail = M.parse_model_detail(body)
    if detail == nil then
        return nil, 'model detail response had no usable id field'
    end
    return detail, nil
end

---Probe whether a model repo is Xet-enabled via the public
---xet-read-token endpoint. Only the presence of `casUrl` is reported;
---the minted accessToken is never stored, logged, or returned.
---@param repo_id string 'owner/name', validated by the caller.
---@param cfg table Live config: api_base.
---@return ai.huggingface.XetProbe probe
function M.repo_xet_probe(repo_id, cfg)
    local url = cfg.api_base .. '/api/models/' .. repo_id .. '/xet-read-token/main'
    local body, _, err = M.get(url, XET_PROBE_TIMEOUT_S, { '-w', '\n%{http_code}' })
    if err ~= nil then
        return { xet_enabled = false, cas_url = nil, note = 'probe failed: ' .. err }
    end
    assert(body ~= nil, 'api.get returned no error but no body')
    local lines = vim.split(body, '\n', { plain = true })
    local code = tonumber(lines[#lines]) or 0
    if code ~= 200 then
        return {
            xet_enabled = false,
            cas_url = nil,
            note = 'Hub answered HTTP ' .. code .. ' (not xet-enabled, or repo not found)',
        }
    end
    table.remove(lines, #lines)
    local payload = table.concat(lines, '\n')
    local ok, decoded = pcall(vim.json.decode, payload)
    if not ok or type(decoded) ~= 'table' then
        return { xet_enabled = false, cas_url = nil, note = 'HTTP 200 but the body was not JSON' }
    end
    local cas_url = take_string(decoded, 'casUrl')
    if cas_url == nil then
        return {
            xet_enabled = false,
            cas_url = nil,
            note = 'HTTP 200 but no casUrl field: xet status undetermined, not claiming enabled',
        }
    end
    return { xet_enabled = true, cas_url = cas_url, note = 'xet-enabled (CAS: ' .. cas_url .. ')' }
end

---One picker line per model entry: id plus the key metadata the Hub
---exposes in the list response.
---@param entries ai.huggingface.ModelEntry[]
---@return string[] lines
function M.model_picker_lines(entries)
    local lines = {}
    for _, entry in ipairs(entries) do
        local shown_tags = {}
        for index = 1, math.min(#entry.tags, TAGS_SHOWN_MAX) do
            shown_tags[#shown_tags + 1] = entry.tags[index]
        end
        lines[#lines + 1] = ('%s | likes %d | downloads %d | pipeline %s | tags: %s'):format(
            entry.id,
            entry.likes,
            entry.downloads,
            entry.pipeline_tag or '-',
            table.concat(shown_tags, ',')
        )
    end
    return lines
end

---Detail float body for one model detail record.
---@param detail ai.huggingface.ModelDetail
---@return string[] lines
function M.model_detail_lines(detail)
    local lines = {
        'id:            ' .. detail.id,
        'author:        ' .. (detail.author or '-'),
        'likes:         ' .. detail.likes,
        'downloads:     ' .. detail.downloads,
        'pipeline tag:  ' .. (detail.pipeline_tag or '-'),
        'license:       ' .. (detail.license or 'unspecified'),
        'last modified: ' .. (detail.last_modified or '-'),
        'sha:           ' .. (detail.sha and detail.sha:sub(1, 12) or '-'),
        'gated:         ' .. tostring(detail.gated),
        'private:       ' .. tostring(detail.private),
        'tags:          ' .. table.concat(detail.tags, ', '),
        '',
        '(the Hub list/detail API exposes no description field; read the model card)',
    }
    return lines
end

---One picker line per dataset entry.
---@param entries ai.huggingface.DatasetEntry[]
---@return string[] lines
function M.dataset_picker_lines(entries)
    local lines = {}
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = ('%s | likes %d | downloads %d'):format(entry.id, entry.likes, entry.downloads)
    end
    return lines
end

---Detail float body for one dataset entry (description ships in the list).
---@param entry ai.huggingface.DatasetEntry
---@return string[] lines
function M.dataset_detail_lines(entry)
    return {
        'id:            ' .. entry.id,
        'author:        ' .. (entry.author or '-'),
        'likes:         ' .. entry.likes,
        'downloads:     ' .. entry.downloads,
        'license:       ' .. (M.license_of(entry.tags) or 'unspecified'),
        'last modified: ' .. (entry.last_modified or '-'),
        'tags:          ' .. table.concat(entry.tags, ', '),
        '',
        'description:',
        entry.description or '(no description in the Hub response)',
    }
end

---One picker line per paper entry.
---@param entries ai.huggingface.PaperEntry[]
---@return string[] lines
function M.paper_picker_lines(entries)
    local lines = {}
    for _, entry in ipairs(entries) do
        local year = (entry.published_at or ''):sub(1, 4)
        lines[#lines + 1] = ('%s (%s) | %s | arxiv:%s'):format(
            entry.title,
            year ~= '' and year or '----',
            table.concat(entry.authors, ', '),
            entry.id
        )
    end
    return lines
end

---Detail float body for one paper entry.
---@param entry ai.huggingface.PaperEntry
---@return string[] lines
function M.paper_detail_lines(entry)
    return {
        'title:        ' .. entry.title,
        'arxiv id:     ' .. entry.id,
        'published:    ' .. (entry.published_at or '-'),
        'authors:      ' .. table.concat(entry.authors, ', '),
        'hub page:     https://huggingface.co/papers/' .. entry.id,
        '',
        'summary:',
        entry.summary or '(no summary in the Hub response)',
    }
end

return M
