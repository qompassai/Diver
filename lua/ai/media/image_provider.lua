-- /qompassai/Diver/lua/ai/media/image_provider.lua
-- Qompass AI Image Generation Backend (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- OpenAI images API via the ported provider module `ai.rose.provider.openai`
-- (Module 1, landing in parallel). The provider module is REQUIRED: it is
-- loaded with pcall and its descriptor shape is validated, so this backend
-- reports unavailable -- with the exact reason -- when the module has not
-- landed yet or its API does not match. The request itself goes through
-- curl in argv form; the API key travels in a 0600 curl config file, never
-- on the command line. No key, no curl, or no provider module means
-- unavailable, never a faked image.

---@class AiMediaOpenAiDescriptor
---@field host string API host the key is bound to, e.g. 'api.openai.com'.
---@field key_env string Environment variable holding the API key.

local M = {}

local PROVIDER_MODULE = 'ai.rose.provider.openai'
local KEY_ENV = 'OPENAI_API_KEY'
local HOST = 'api.openai.com'
local ENDPOINT = 'https://api.openai.com/v1/images/generations'
local MODEL = 'dall-e-3'
local PROMPT_CHARS_MAX = 4000
local REQUEST_TIMEOUT_S = 120
local RESPONSE_MAX_BYTES = 32 * 1024 * 1024
local BODY_MAX_BYTES = 64 * 1024

-- Loads the ported provider and validates its descriptor shape. Anything
-- unexpected is a mismatch, reported as unavailable -- never guessed at.
---@return AiMediaOpenAiDescriptor|nil, string|nil
local function load_provider()
    local ok, mod = pcall(require, PROVIDER_MODULE)
    if not ok then
        return nil, PROVIDER_MODULE .. ' is not loaded yet (Module 1 has not landed)'
    end
    if type(mod) ~= 'table' then
        return nil, PROVIDER_MODULE .. ' did not return a descriptor table'
    end
    ---@cast mod AiMediaOpenAiDescriptor
    if mod.host ~= HOST then
        return nil, PROVIDER_MODULE .. ' host mismatch: expected ' .. HOST
    end
    if mod.key_env ~= KEY_ENV then
        return nil, PROVIDER_MODULE .. ' key_env mismatch: expected ' .. KEY_ENV
    end
    return mod, nil
end

---@return string|nil key, string|nil err
local function read_key()
    local key = vim.env[KEY_ENV]
    if type(key) ~= 'string' or key == '' then
        return nil, KEY_ENV .. ' is not set; export it before generating images'
    end
    if #key > 16384 or key:find('[%c]') then
        return nil, KEY_ENV .. ' has an invalid format'
    end
    return key, nil
end

---@param ext string
---@return string|nil, string|nil
local function default_out_path(ext)
    local cache = vim.fn.stdpath('cache')
    if type(cache) ~= 'string' or cache == '' then
        return nil, 'could not resolve stdpath cache'
    end
    local dir = cache .. '/ai-media'
    if vim.fn.mkdir(dir, 'p') == 0 then
        return nil, 'could not create output directory: ' .. dir
    end
    return dir .. '/img-' .. tostring(os.time()) .. '.' .. ext, nil
end

-- Writes `content` to a temp file with 0600 permissions.
---@param content string File content.
---@param suffix string Suffix appended to the temp name, e.g. '.json'.
---@return string|nil, string|nil path or (nil, err)
local function write_private_temp(content, suffix)
    local path = vim.fn.tempname() .. suffix
    local file, err = io.open(path, 'w')
    if not file then
        return nil, 'could not write temp file: ' .. tostring(err)
    end
    file:write(content)
    file:close()
    vim.fn.setfperm(path, 'rw-------')
    return path, nil
end

---@return boolean available
---@return string reason
local function detect()
    if vim.fn.executable('curl') ~= 1 then
        return false, 'curl not found; image generation shells out to curl'
    end
    local _, key_err = read_key()
    if key_err then
        return false, key_err
    end
    local _, provider_err = load_provider()
    if provider_err then
        return false, provider_err
    end
    return true, 'OpenAI images via ' .. PROVIDER_MODULE
end

---@param opts AiMediaGenerateOpts
---@param cb AiMediaCallback
local function generate(opts, cb)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(cb) == 'function', 'cb must be a function')
    local prompt = opts.prompt
    if type(prompt) ~= 'string' or prompt == '' then
        cb('no prompt given', nil)
        return
    end
    if #prompt > PROMPT_CHARS_MAX then
        cb('prompt exceeds ' .. PROMPT_CHARS_MAX .. ' characters', nil)
        return
    end
    local key, key_err = read_key()
    if not key then
        cb(key_err, nil)
        return
    end
    local descriptor, provider_err = load_provider()
    if not descriptor then
        cb(provider_err, nil)
        return
    end
    local size = opts.size or '1024x1024'
    if type(size) ~= 'string' or not size:match('^%d+x%d+$') then
        cb('size must look like 1024x1024', nil)
        return
    end
    ---@type string
    local out_path
    if opts.out_path == nil then
        local resolved, err = default_out_path('png')
        if not resolved then
            cb(err, nil)
            return
        end
        out_path = resolved
    else
        local custom = opts.out_path
        assert(type(custom) == 'string' and custom ~= '', 'output path must be a non-empty string')
        out_path = custom
    end
    local body = { model = MODEL, prompt = prompt, size = size, n = 1, response_format = 'b64_json' }
    local encoded = vim.json.encode(body)
    assert(type(encoded) == 'string', 'request body must encode')
    if #encoded > BODY_MAX_BYTES then
        cb('request body too large', nil)
        return
    end
    local body_path, body_err = write_private_temp(encoded, '.json')
    if not body_path then
        cb(body_err, nil)
        return
    end
    -- The key goes in a 0600 curl config file so it never appears in `ps`.
    local cfg_path, cfg_err = write_private_temp('header = "Authorization: Bearer ' .. key .. '"\n', '.curlcfg')
    if not cfg_path then
        vim.fn.delete(body_path)
        cb(cfg_err, nil)
        return
    end
    local response_path = vim.fn.tempname() .. '.json'
    local argv = {
        'curl',
        '--fail-with-body',
        '-sS',
        '--max-time',
        tostring(REQUEST_TIMEOUT_S),
        '-X',
        'POST',
        '--config',
        cfg_path,
        '-H',
        'Content-Type: application/json',
        '--data-binary',
        '@' .. body_path,
        '-o',
        response_path,
        ENDPOINT,
    }
    local done = false
    local function finish(err)
        if done then
            return
        end
        done = true
        vim.fn.delete(body_path)
        vim.fn.delete(cfg_path)
        vim.schedule(function()
            if err then
                vim.fn.delete(response_path)
                cb(err, nil)
                return
            end
            local file = io.open(response_path, 'r')
            if not file then
                cb('no response file from image API', nil)
                return
            end
            local raw = file:read('*a')
            file:close()
            vim.fn.delete(response_path)
            if type(raw) ~= 'string' or raw == '' then
                cb('image API returned an empty response', nil)
                return
            end
            if #raw > RESPONSE_MAX_BYTES then
                cb('image API response exceeds size limit', nil)
                return
            end
            local ok, decoded = pcall(vim.json.decode, raw)
            if not ok or type(decoded) ~= 'table' then
                cb('image API returned invalid JSON', nil)
                return
            end
            local data = decoded.data
            if type(data) ~= 'table' or type(data[1]) ~= 'table' then
                cb('image API response has no image data', nil)
                return
            end
            local b64 = data[1].b64_json
            if type(b64) ~= 'string' or b64 == '' then
                cb('image API response has no image payload', nil)
                return
            end
            local png = vim.base64.decode(b64)
            local out = io.open(out_path, 'wb')
            if not out then
                cb('could not write image file: ' .. out_path, nil)
                return
            end
            out:write(png)
            out:close()
            local stat = vim.uv.fs_stat(out_path)
            local bytes = (stat and stat.size) or 0
            cb(nil, { path = out_path, bytes = bytes, backend = 'image-openai' })
        end)
    end
    local ok, proc = pcall(vim.system, argv, { text = true }, function(outcome)
        if done then
            return
        end
        if outcome.code ~= 0 then
            finish('image API request failed (exit ' .. outcome.code .. ')')
            return
        end
        finish(nil)
    end)
    if not ok or proc == nil then
        finish('could not start curl')
    end
end

-- Assemble the backend only once all fields exist; a partial literal
-- would trip the strict missing-fields check.
---@type AiMediaBackend
local backend = { kind = 'image', detect = detect, generate = generate }

M.backend = backend
M.PROMPT_CHARS_MAX = PROMPT_CHARS_MAX
M.PROVIDER_MODULE = PROVIDER_MODULE

return M
