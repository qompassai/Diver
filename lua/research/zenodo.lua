-- /qompassai/Diver/lua/research/zenodo.lua
-- Qompass AI Diver Zenodo Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Zenodo deposits from inside Neovim (REST API,
-- https://developers.zenodo.org/#rest-api): list your deposits, inspect
-- one, create a DRAFT deposition from a manuscript directory, and
-- upload files to a draft's bucket.
--
-- Deliberate boundaries:
-- - Drafts only. This module has no publish function on purpose:
--   publishing a deposit is Matt's manual act on the Zenodo website.
-- - Secrets and identity material follow Matt's convention (the same
--   sources his qsync release script reads). The Zenodo API token
--   resolves in this order: ZENODO_TOKEN environment override, then the
--   sops+age automation tier via the research-secret accessor (field
--   zenodo_token; tier README at ~/.local/share/diver/secrets/README.md),
--   then pass at 'api/zenodo', then a setup() token (last-resort
--   programmatic override for tests, never persisted anywhere). A tier
--   value of REPLACE_ME counts as not-yet-populated. pass also supplies
--   the Zenodo metadata defaults at 'zen/affil' and 'zen/community',
--   author identity at 'auth/fullname' / 'auth/givenname' /
--   'auth/lastname', and the ORCID iD at 'orcid/id'.
-- - pass cannot decrypt from a non-interactive context when the GPG
--   agent is locked (the tier exists to serve automation headlessly):
--   every lookup here degrades to a structured 'secret unavailable'
--   result. No crash, no retry loop, and no fallback ever writes a
--   secret to disk or a buffer.
-- - Zenodo also offers an OAI-PMH endpoint; it is a read-only harvest
--   protocol for aggregators and is intentionally not built on here.
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

local API_BASE_URL = 'https://zenodo.org'
local DEFAULT_CREATOR_NAME = 'Porter, Matthew'
local DEFAULT_ORCID_ID = '0000-0002-0302-4812'
local DISPLAY_LINES_MAX = 200
local FILE_SIZE_MAX_BYTES = 100 * 1024 * 1024
local PASS_AFFILIATION_PATH = 'zen/affil'
local PASS_COMMUNITY_PATH = 'zen/community'
local PASS_FULLNAME_PATH = 'auth/fullname'
local PASS_GIVENNAME_PATH = 'auth/givenname'
local PASS_LASTNAME_PATH = 'auth/lastname'
local PASS_ORCID_PATH = 'orcid/id'
local PASS_TOKEN_PATH = 'api/zenodo'
local PLACEHOLDER_SECRET = 'REPLACE_ME'
local REQUEST_TIMEOUT_SEC = 30
local RESEARCH_SECRET_BIN = fn.expand('~/.local/bin/research-secret')
local SECRET_FIELD_TOKEN = 'zenodo_token'
local SECRET_TIMEOUT_MS = 5000

---@class ZenodoConfig
---@field api_base string
---@field pass_path string
---@field secret_field string research-secret field for the token ('' disables the tier)
---@field token string|nil setup-only token (never persisted)

---@type ZenodoConfig
local config = {
    api_base = API_BASE_URL,
    pass_path = PASS_TOKEN_PATH,
    secret_field = SECRET_FIELD_TOKEN,
    token = nil,
}

---Read a secret from pass(1). Same pattern as research.orcid, plus the
---locked-agent failure mode: when pass cannot decrypt (agent locked,
---entry missing, or pass absent) this returns nil with `unavailable`
---true — a structured degradation, never an error.
---@param pass_path string
---@return string|nil secret
---@return boolean unavailable true when pass could not provide it
local function get_pass_secret(pass_path)
    assert(type(pass_path) == 'string', 'pass_path must be a string')
    if fn.executable('pass') ~= 1 then
        return nil, true
    end
    local ok, result = pcall(vim.system, { 'pass', 'show', pass_path }, { text = true })
    if not ok then
        return nil, true
    end
    local finished = result:wait(5000)
    if finished.code ~= 0 then
        return nil, true
    end
    local secret = vim.trim(finished.stdout or '')
    if secret == '' then
        return nil, true
    end
    return secret, false
end

---Read a secret from the sops+age automation tier via the
---research-secret accessor (absolute path: a non-interactive PATH lacks
---~/.local/bin; the tier is documented in
---~/.local/share/diver/secrets/README.md). Output is never logged. The
---placeholder value counts as not-yet-populated. Any failure — accessor
---missing, key refused, field absent — returns nil with `unavailable`
---true: the same structured degradation as the pass path.
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

---Resolve the Zenodo token: ZENODO_TOKEN environment override first,
---then the sops+age tier (research-secret), then pass at
---config.pass_path, then a setup() token (test seam).
---@return string|nil token
---@return boolean secret_unavailable true when pass was consulted and failed
local function get_token()
    local from_env = os.getenv('ZENODO_TOKEN')
    if from_env and from_env ~= '' then
        return from_env, false
    end
    local unavailable = false
    if config.secret_field and config.secret_field ~= '' then
        local from_tier, tier_unavailable = get_research_secret(config.secret_field)
        if from_tier then
            return from_tier, false
        end
        unavailable = tier_unavailable
    end
    local from_pass, pass_unavailable = get_pass_secret(config.pass_path)
    if from_pass then
        return from_pass, false
    end
    unavailable = unavailable or pass_unavailable
    if config.token and config.token ~= '' then
        return config.token, false
    end
    return nil, unavailable
end

---@param secret_unavailable boolean
---@return string
local function token_error(secret_unavailable)
    if secret_unavailable then
        return 'Zenodo token unavailable: ZENODO_TOKEN is unset and no token '
            .. 'could be read from the research-secret tier or pass entry '
            .. config.pass_path
            .. ' (secret unavailable — locked agent, or tier not yet populated?)'
    end
    return 'Zenodo token not configured: set the ZENODO_TOKEN environment '
        .. 'variable, populate the research-secret tier (field zenodo_token), '
        .. 'or store a token in pass at '
        .. config.pass_path
        .. ' (never in a config file)'
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

---Author identity for deposit metadata, sourced from pass so Neovim,
---qsync, and Zenodo records never disagree. Any piece pass cannot
---provide falls back to the recorded public identity.
---@return table creator { name, orcid, affiliation? }
local function author_identity()
    local lastname = get_pass_secret(PASS_LASTNAME_PATH)
    local givenname = get_pass_secret(PASS_GIVENNAME_PATH)
    local name
    if lastname and givenname then
        name = lastname .. ', ' .. givenname
    else
        name = get_pass_secret(PASS_FULLNAME_PATH) or DEFAULT_CREATOR_NAME
    end
    local creator = {
        name = name,
        orcid = get_pass_secret(PASS_ORCID_PATH) or DEFAULT_ORCID_ID,
    }
    local affiliation = get_pass_secret(PASS_AFFILIATION_PATH)
    if affiliation then
        creator.affiliation = affiliation
    end
    return creator
end

---One bounded, synchronous HTTPS request. Returns decoded JSON.
---@param method string 'GET'|'POST'|'PUT'
---@param url string full URL
---@param token string
---@param json_body? table encoded as the request body when present
---@param upload_path? string local file streamed as the request body
---@return table|nil result
---@return string|nil err
local function request(method, url, token, json_body, upload_path)
    local cmd = {
        'curl',
        '--silent',
        '--show-error',
        '--fail',
        '--max-time',
        tostring(REQUEST_TIMEOUT_SEC),
        '--request',
        method,
        '--header',
        'Authorization: Bearer ' .. token,
        '--header',
        'Accept: application/json',
    }
    if json_body ~= nil then
        cmd[#cmd + 1] = '--header'
        cmd[#cmd + 1] = 'Content-Type: application/json'
        cmd[#cmd + 1] = '--data'
        cmd[#cmd + 1] = vim.json.encode(json_body)
    end
    if upload_path ~= nil then
        cmd[#cmd + 1] = '--upload-file'
        cmd[#cmd + 1] = upload_path
    end
    cmd[#cmd + 1] = url
    local result = vim.system(cmd, { text = true }):wait(REQUEST_TIMEOUT_SEC * 1000 + 5000)
    if result.code ~= 0 then
        local detail = vim.trim(result.stderr or '')
        if detail == '' then
            detail = 'HTTP request failed'
        end
        return nil, ('Zenodo request failed: %s'):format(detail)
    end
    if result.stdout == nil or result.stdout == '' then
        return {}, nil
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'Zenodo response was not valid JSON'
    end
    return decoded, nil
end

---@param id string|integer
---@return boolean
local function is_valid_id(id)
    return tostring(id):match('^%d+$') ~= nil
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

---@param deposition table
---@return string[]
local function deposition_lines(deposition)
    local metadata = deposition.metadata or {}
    local lines = {
        ('## %s (id %s)'):format(metadata.title or '(untitled)', tostring(deposition.id)),
        '',
        ('- State: %s'):format(deposition.state or 'unknown'),
        ('- DOI: %s'):format(deposition.doi or metadata.doi or 'none yet'),
        ('- Upload type: %s'):format(metadata.upload_type or 'unknown'),
        ('- Journal: %s'):format(metadata.journal_title or 'not recorded'),
        '',
        '### Files',
        '',
    }
    local files = deposition.files or {}
    if #files == 0 then
        lines[#lines + 1] = '- (none)'
    end
    for _, file in ipairs(files) do
        lines[#lines + 1] = ('- %s (%s bytes)'):format(
            file.filename or file.key or '?',
            tostring(file.filesize or file.size or '?')
        )
    end
    return lines
end

---List your Zenodo deposits (newest first, as the API returns them).
---@return table[]|nil depositions
---@return string|nil err
function M.list_depositions()
    local token, secret_unavailable = get_token()
    if not token then
        return nil, token_error(secret_unavailable)
    end
    local result, err = request('GET', config.api_base .. '/api/deposit/depositions', token)
    if not result then
        return nil, err
    end
    return result, nil
end

---Fetch one deposition by id.
---@param id string|integer
---@return table|nil deposition
---@return string|nil err
function M.get_deposition(id)
    if not is_valid_id(id) then
        return nil, ('invalid Zenodo deposition id: %s'):format(tostring(id))
    end
    local token, secret_unavailable = get_token()
    if not token then
        return nil, token_error(secret_unavailable)
    end
    return request('GET', ('%s/api/deposit/depositions/%s'):format(config.api_base, tostring(id)), token)
end

---Extract an abstract/body excerpt from manuscript text for the draft
---description, bounded so a long manuscript cannot flood the payload.
---@param text string
---@return string
local function description_from(text)
    local abstract = text:match('# Abstract%s*\n(.-)\n# ') or text:match('\\begin{abstract}(.-)\\end{abstract}')
    if abstract then
        abstract = vim.trim(abstract:gsub('[#>*`_]', ''))
        if #abstract > 2000 then
            abstract = abstract:sub(1, 2000)
        end
        if abstract ~= '' then
            return abstract
        end
    end
    return 'Draft created from a local manuscript directory by the Diver '
        .. 'research workflow. Edit this description before deposit.'
end

---Create a DRAFT deposition from a manuscript directory. Metadata is
---mapped from the manuscript (research.manuscript) and, when a journal
---key is given, the journal profile (research.journal). The draft is
---never published by this module.
---@param dir string manuscript directory
---@param journal_key? string journal profile key
---@return table|nil deposition
---@return string|nil err
function M.create_draft(dir, journal_key)
    assert(type(dir) == 'string' and dir ~= '', 'manuscript directory must be a string')
    local token, secret_unavailable = get_token()
    if not token then
        return nil, token_error(secret_unavailable)
    end
    local submission = require('research.submission')
    local manuscript = require('research.manuscript')
    local scan = submission.scan(fs.normalize(dir))
    table.sort(scan.manuscript)
    local manuscript_path = nil
    for _, path in ipairs(scan.manuscript) do
        if path:match('%.md$') or path:match('%.tex$') then
            manuscript_path = path
            break
        end
    end
    if not manuscript_path then
        return nil, ('no manuscript (.md/.tex) found in %s'):format(dir)
    end
    local text = table.concat(fn.readfile(manuscript_path), '\n')
    local metadata = manuscript.metadata(text)
    local title = metadata.full_title or text:match('title:%s*"([^"]+)"') or metadata.title
    if not title or title == '' then
        return nil, 'manuscript has no title (add a Full Title line or YAML title)'
    end
    local payload_metadata = {
        creators = { author_identity() },
        description = description_from(text),
        publication_type = 'article',
        title = title,
        upload_type = 'publication',
    }
    local community = get_pass_secret(PASS_COMMUNITY_PATH)
    if community then
        payload_metadata.communities = { { identifier = community } }
    end
    if metadata.keywords and metadata.keywords ~= '' then
        local keywords = {}
        for word in metadata.keywords:gmatch('[^,;]+') do
            keywords[#keywords + 1] = vim.trim(word)
        end
        payload_metadata.keywords = keywords
    end
    if journal_key and journal_key ~= '' then
        local journal = require('research.journal')
        local profile = journal.get(journal_key)
        payload_metadata.journal_title = profile.name
    end
    return request('POST', config.api_base .. '/api/deposit/depositions', token, {
        metadata = payload_metadata,
    })
end

---Upload a local file to a draft deposition's bucket.
---@param id string|integer deposition id
---@param path string local file path
---@return table|nil file_entry
---@return string|nil err
function M.upload_file(id, path)
    assert(type(path) == 'string' and path ~= '', 'upload path must be a string')
    if fn.filereadable(path) ~= 1 then
        return nil, ('file not readable: %s'):format(path)
    end
    local size = fn.getfsize(path)
    if size < 0 or size > FILE_SIZE_MAX_BYTES then
        return nil, ('file size %d exceeds the %d-byte upload bound'):format(size, FILE_SIZE_MAX_BYTES)
    end
    local deposition, err = M.get_deposition(id)
    if not deposition then
        return nil, err
    end
    local bucket = deposition.links and deposition.links.bucket
    if not bucket or bucket == '' then
        return nil, 'deposition has no upload bucket (is it still a draft?)'
    end
    local token, secret_unavailable = get_token()
    if not token then
        return nil, token_error(secret_unavailable)
    end
    local filename = fs.basename(path):gsub('[^%w%._%-]', function(char)
        return ('%%%02X'):format(char:byte())
    end)
    return request('PUT', bucket .. '/' .. filename, token, nil, path)
end

---Show your deposits in a scratch buffer.
---@return nil
function M.show_list()
    local depositions, err = M.list_depositions()
    if not depositions then
        notify_error(('Zenodo: %s'):format(err))
        return
    end
    local lines = { '# Zenodo Deposits', '' }
    if #depositions == 0 then
        lines[#lines + 1] = '(no deposits found)'
    end
    for _, deposition in ipairs(depositions) do
        for _, line in ipairs(deposition_lines(deposition)) do
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = ''
    end
    show_lines('Zenodo Deposits', lines)
end

---Show one deposition in a scratch buffer.
---@param id string|integer
---@return nil
function M.show_deposition(id)
    local deposition, err = M.get_deposition(id)
    if not deposition then
        notify_error(('Zenodo: %s'):format(err))
        return
    end
    show_lines('Zenodo Deposition', deposition_lines(deposition))
end

---@param opts? ZenodoConfig partial overrides (api_base, pass_path, secret_field, token)
---@return nil
function M.setup(opts)
    opts = opts or {}
    if opts.api_base ~= nil then
        assert(type(opts.api_base) == 'string', 'api_base must be a string')
        config.api_base = opts.api_base
    end
    if opts.pass_path ~= nil then
        assert(type(opts.pass_path) == 'string', 'pass_path must be a string')
        config.pass_path = opts.pass_path
    end
    if opts.secret_field ~= nil then
        assert(type(opts.secret_field) == 'string', 'secret_field must be a string')
        config.secret_field = opts.secret_field
    end
    if opts.token ~= nil then
        assert(type(opts.token) == 'string', 'token must be a string')
        config.token = opts.token
    end

    api.nvim_create_user_command('ZenodoList', function()
        M.show_list()
    end, { desc = 'List your Zenodo deposits' })

    api.nvim_create_user_command('ZenodoShow', function(cmd_opts)
        M.show_deposition(cmd_opts.args)
    end, {
        nargs = 1,
        desc = 'Show one Zenodo deposition by id',
    })

    api.nvim_create_user_command('ZenodoDraft', function(cmd_opts)
        local dir = vim.uv.cwd() or fn.getcwd()
        local journal_key = nil
        local args = cmd_opts.fargs
        if #args == 1 then
            if fn.isdirectory(args[1]) == 1 then
                dir = args[1]
            else
                journal_key = args[1]
            end
        elseif #args >= 2 then
            dir = args[1]
            journal_key = args[2]
        end
        local deposition, err = M.create_draft(dir, journal_key)
        if not deposition then
            notify_error(('Zenodo: %s'):format(err))
            return
        end
        vim.notify(('Zenodo: draft %s created (not published)'):format(tostring(deposition.id)), vim.log.levels.INFO)
    end, {
        nargs = '*',
        complete = 'dir',
        desc = 'Create a Zenodo DRAFT from a manuscript dir [dir] [journal] (never publishes)',
    })

    api.nvim_create_user_command('ZenodoUpload', function(cmd_opts)
        if #cmd_opts.fargs < 2 then
            vim.notify('ZenodoUpload: usage :ZenodoUpload <id> <file>', vim.log.levels.WARN)
            return
        end
        local entry, err = M.upload_file(cmd_opts.fargs[1], cmd_opts.fargs[2])
        if not entry then
            notify_error(('Zenodo: %s'):format(err))
            return
        end
        vim.notify('Zenodo: file uploaded to draft bucket', vim.log.levels.INFO)
    end, {
        nargs = '+',
        complete = 'file',
        desc = 'Upload a file to a Zenodo draft bucket',
    })
end

return M
