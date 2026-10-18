-- /qompassai/Diver/lua/ai/rose/provider/openai.lua
-- OpenAI legacy provider class (Tiger Style)
---@module 'ai.rose.provider.openai'
-- Historical provider-class interface kept for compatibility. The modern
-- ai.rose.providers registry is the preferred native interface.

-- Inlined logger (formerly ai.rose.logger, whose only consumer was
-- this file). Minimal port of rose.nvim's logger: error/warning/info/
-- debug with a bounded on-disk log for errors and debug lines. Debug
-- output is gated on the DEBUG_ROSE environment variable. This never
-- overrides vim.notify with a plugin; native notification stays.

local logger = {
    _plugin_name = 'diver.rose',
    _logfile = vim.fn.stdpath('state') .. '/diver-rose.log',
    _max_log_lines = 10000,
    _debug_enabled = vim.env.DEBUG_ROSE ~= nil,
}

---@param path string
---@return string content  -- '' when the file cannot be read
local function read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return ''
    end
    local content = file:read('*a')
    file:close()
    return content or ''
end

---@param path string
---@param content string
---@return boolean ok
local function write_file(path, content)
    local file = io.open(path, 'w')
    if not file then
        return false
    end
    local written = file:write(content)
    local closed = file:close()
    return written ~= nil and closed ~= nil
end

-- Keep only the newest _max_log_lines lines so the log cannot grow without bound.
---@return string limited
local function limit_logfile_lines()
    local lines = vim.split(read_file(logger._logfile), '\n')
    while #lines > logger._max_log_lines do
        table.remove(lines, 1)
    end
    return table.concat(lines, '\n')
end

---@param msg string
---@param kind string
local function write_to_logfile(msg, kind)
    local entry = string.format('[%s] %s: [%s] %s\n', os.date('%Y-%m-%d %H:%M:%S'), logger._plugin_name, kind, msg)
    write_file(logger._logfile, limit_logfile_lines() .. entry)
end

---@param msg string
---@param kind string
---@param level integer vim.log.levels value
local function log(msg, kind, level)
    assert(type(msg) == 'string', 'logger: msg must be a string')
    if kind == 'ErrorMsg' or kind == 'Debug' then
        write_to_logfile(msg, kind)
    end
    if kind ~= 'Debug' then
        vim.schedule(function()
            vim.notify(msg, level, { title = logger._plugin_name .. ' ' .. kind })
        end)
    end
end

---@param msg string
function logger.error(msg)
    log(msg, 'ErrorMsg', vim.log.levels.ERROR)
end

---@param msg string
function logger.warning(msg)
    log(msg, 'WarningMsg', vim.log.levels.WARN)
end

---@param msg string
function logger.info(msg)
    log(msg, 'Normal', vim.log.levels.INFO)
end

---@param msg string
function logger.debug(msg)
    if logger._debug_enabled then
        log(msg, 'Debug', vim.log.levels.DEBUG)
    end
end

-- Inlined provider utils (formerly ai.rose.utils, whose only consumer
-- was this file). Ports only what the provider classes need from
-- rose.nvim's utils (filter_payload_parameters, parse_raw_response);
-- key_from_command runs a key-retrieval argv command through
-- vim.system instead of the original io.popen shell string.

local KEY_BYTES_MAX = 16384
local KEY_COMMAND_ARGS_MAX = 32

-- Keep only the provider's documented parameters in the outgoing payload.
-- Nested parameter tables copy the payload's own same-named keys, matching
-- the historical rose.nvim behavior exactly.
---@param valid_parameters table<string, boolean|table>
---@param payload table
---@return table filtered
local function filter_payload_parameters(valid_parameters, payload)
    assert(type(valid_parameters) == 'table', 'valid_parameters must be a table')
    assert(type(payload) == 'table', 'payload must be a table')
    local new_payload = {}
    for key, value in pairs(valid_parameters) do
        if type(value) == 'table' then
            if new_payload[key] == nil then
                new_payload[key] = {}
            end
            for nested_key, _ in pairs(value) do
                new_payload[key][nested_key] = payload[nested_key]
            end
        else
            new_payload[key] = payload[key]
        end
    end
    return new_payload
end

-- Join raw subprocess output lines into one response string.
---@param response string|string[]|nil
---@return string|nil joined
local function parse_raw_response(response)
    if response == nil then
        return nil
    end
    if type(response) == 'table' then
        return table.concat(response, ' ')
    end
    return response
end

-- Run a key-retrieval command (the api_key table form) as an explicit argv
-- array via vim.system. Never builds a shell string from the command.
---@param argv string[] key-retrieval argv array
---@return string? key  -- whitespace-stripped key, nil on failure
---@return string? err
local function key_from_command(argv)
    if type(argv) ~= 'table' or #argv == 0 or #argv > KEY_COMMAND_ARGS_MAX then
        return nil, 'key command must be a non-empty argv array'
    end
    for _, arg in ipairs(argv) do
        if type(arg) ~= 'string' or arg == '' or arg:find('\0', 1, true) then
            return nil, 'key command argv must be non-empty strings without NUL'
        end
    end
    local ok, result = pcall(vim.system, argv, { text = true })
    if not ok then
        return nil, 'key command failed to start: ' .. tostring(result)
    end
    local completed = result:wait()
    if completed.code ~= 0 then
        return nil, 'key command exited ' .. tostring(completed.code)
    end
    local key = (completed.stdout or ''):gsub('%s+', '')
    if key == '' then
        return nil, 'key command returned an empty key'
    end
    if #key > KEY_BYTES_MAX then
        return nil, 'key command returned an overlong key'
    end
    return key, nil
end

---@class AiRoseProviderOpenAI
---@field endpoint string
---@field api_key string|string[]|nil
---@field name string
local OpenAI = {}
OpenAI.__index = OpenAI

-- Available API parameters for OpenAI
-- https://platform.openai.com/docs/api-reference/chat
local AVAILABLE_API_PARAMETERS = {
    -- required
    messages = true,
    model = true,
    -- optional
    frequency_penalty = true,
    logit_bias = true,
    logprobs = true,
    top_logprobs = true,
    max_tokens = true,
    max_completion_tokens = true,
    presence_penalty = true,
    seed = true,
    stop = true,
    stream = true,
    temperature = true,
    top_p = true,
    tools = true,
    tool_choice = true,
}

-- Creates a new OpenAI instance
---@param endpoint string
---@param api_key string|string[]|nil
---@return AiRoseProviderOpenAI
function OpenAI:new(endpoint, api_key)
    return setmetatable({
        endpoint = endpoint,
        api_key = api_key,
        name = 'openai',
    }, self)
end

-- Placeholder for setting model (not implemented)
---@param _ any
function OpenAI:set_model(_) end

-- Preprocesses the payload before sending to the API
---@param payload table
---@return table
function OpenAI:preprocess_payload(payload)
    for _, message in ipairs(payload.messages) do
        message.content = message.content:gsub('^%s*(.-)%s*$', '%1')
    end
    -- Changes according to beta limitations of the reasoning API
    -- https://platform.openai.com/docs/guides/reasoning
    if payload.model and string.find(payload.model, 'o1', 1, true) then
        -- remove system prompt
        if payload.messages[1] and payload.messages[1].role == 'system' then
            table.remove(payload.messages, 1)
        end
        payload.logprobs = nil
        payload.temperature = 1
        payload.top_p = 1
        payload.top_n = 1
        payload.presence_penalty = 0
        payload.frequency_penalty = 0
    end
    return filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

-- Returns the curl parameters for the API request
---@return table
function OpenAI:curl_params()
    return {
        self.endpoint,
        '-H',
        'authorization: Bearer ' .. self.api_key,
    }
end

-- Verifies the API key or executes a routine to retrieve it
---@return boolean
function OpenAI:verify()
    local current_key = self.api_key
    if type(current_key) == 'table' then
        local key, err = key_from_command(current_key)
        if not key then
            logger.error('Error reading API key of ' .. self.name .. ': ' .. tostring(err))
            return false
        end
        self.api_key = key
        return true
    elseif type(current_key) == 'string' and current_key:match('%S') then
        return true
    else
        logger.error('Error with API key ' .. self.name .. ' ' .. vim.inspect(self.api_key))
        return false
    end
end

-- Processes the stdout from the API response
---@param response string
---@return string|nil
function OpenAI:process_stdout(response)
    if response:match('chat%.completion%.chunk') or response:match('chat%.completion') then
        local success, content = pcall(vim.json.decode, response)
        if
            success
            and type(content) == 'table'
            and type(content.choices) == 'table'
            and type(content.choices[1]) == 'table'
            and type(content.choices[1].delta) == 'table'
            and type(content.choices[1].delta.content) == 'string'
        then
            return content.choices[1].delta.content
        else
            logger.debug('Could not process response: ' .. response)
        end
    end
end

-- Processes the onexit event from the API response
---@param res string
function OpenAI:process_onexit(res)
    local success, parsed = pcall(vim.json.decode, res)
    if not success or type(parsed) ~= 'table' then
        return
    end
    if type(parsed.error) == 'table' and type(parsed.error.message) == 'string' then
        logger.error(
            string.format(
                'OpenAI - code: %s message: %s type: %s',
                parsed.error.code,
                parsed.error.message,
                parsed.error.type
            )
        )
    elseif
        type(parsed.choices) == 'table'
        and type(parsed.choices[1]) == 'table'
        and type(parsed.choices[1].message) == 'table'
        and type(parsed.choices[1].message.content) == 'string'
    then
        return parsed.choices[1].message.content
    end
end

-- Blocking curl GET through argv-form vim.system.
---@param url string
---@param api_key string
---@return string? stdout
local function curl_get(url, api_key)
    local ok, result = pcall(vim.system, {
        'curl',
        '-sS',
        url,
        '-H',
        'Authorization: Bearer ' .. api_key,
    }, { text = true })
    if not ok then
        return nil
    end
    local completed = result:wait()
    if completed.code ~= 0 then
        return nil
    end
    return completed.stdout
end

-- Returns the list of available models
---@param online boolean Whether to fetch models online
---@return string[]
function OpenAI:get_available_models(online)
    local ids = {
        'gpt-4o',
        'gpt-4-turbo',
        'gpt-4-turbo-2024-04-09',
        'chatgpt-4o-latest',
        'gpt-4-turbo-preview',
        'gpt-3.5-turbo-instruct',
        'gpt-4-0125-preview',
        'gpt-3.5-turbo-0125',
        'gpt-3.5-turbo',
        'o1-preview-2024-09-12',
        'o1-preview',
        'gpt-4o-mini',
        'gpt-4o-2024-05-13',
        'gpt-4o-mini-2024-07-18',
        'gpt-4-1106-preview',
        'gpt-3.5-turbo-16k',
        'gpt-4o-2024-08-06',
        'gpt-3.5-turbo-1106',
        'gpt-4-0613',
        'o1-mini',
        'gpt-4',
        'o1-mini-2024-09-12',
        'gpt-3.5-turbo-instruct-0914',
    }
    if online and self:verify() then
        local key = self.api_key
        if type(key) ~= 'string' then
            logger.error('OpenAI - API key unavailable after verification')
            return ids
        end
        local stdout = curl_get('https://api.openai.com/v1/models', key)
        local parsed_response = parse_raw_response(stdout)
        ids = {}
        if not parsed_response then
            logger.error('OpenAI - No model response received')
            return ids
        end
        self:process_onexit(parsed_response)
        local success, decoded = pcall(vim.json.decode, parsed_response)
        if success and type(decoded) == 'table' and type(decoded.data) == 'table' then
            for _, item in ipairs(decoded.data) do
                if type(item) == 'table' and type(item.id) == 'string' then
                    table.insert(ids, item.id)
                end
            end
        end
    end
    return ids
end

return OpenAI
