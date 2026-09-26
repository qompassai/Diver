-- /qompassai/Diver/lua/ai/rose/init.lua
-- Native Rose entrypoint: chat, agent, flow, MCP (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Requiring or setting up Rose never loads the legacy provider classes.
-- setup() is idempotent and spawns nothing; commands are registered once.

local M = { did_setup = false, operations = {}, generation = 0 }

local writing_kinds = { Agent = true, Flow = true }

---@param err any
local function notify_error(err)
    vim.notify('Rose: ' .. tostring(err), vim.log.levels.ERROR)
end

---@return boolean? ok
---@return string? err
local function ready()
    if not M.did_setup then
        local ok, err = M.setup()
        if not ok then
            return nil, err
        end
    end
    return true
end

---@return integer bufnr
local function source_buffer()
    local current = vim.api.nvim_get_current_buf()
    local ui = package.loaded['ai.rose.ui']
    if not ui or current ~= ui.buffer then
        M.context_buf = current
    end
    return M.context_buf
end

---@param text string?
---@param label string
---@param action fun(value: string)
local function prompt(text, label, action)
    if text and not text:match('^%s*$') then
        action(text)
        return
    end
    source_buffer()
    vim.ui.input({ prompt = label .. ': ' }, function(input)
        if input and not input:match('^%s*$') then
            action(input)
        end
    end)
end

-- Track one user-facing operation with a cancellation slot and a
-- generation fence so stale callbacks never print into a new session.
---@param kind string
---@param callback fun(err: string?, result: any?)?
---@param start fun(done: fun(err: string?, result: any?), context: integer): table?
---@return table? token
local function operation(kind, callback, start)
    local ok, err = ready()
    if not ok then
        if callback then
            callback(err)
        else
            notify_error(err)
        end
        return
    end
    if writing_kinds[kind] and M.writer then
        err = 'a writing workflow is already running; use :RoseStop before starting another'
        if callback then
            callback(err)
        else
            notify_error(err)
        end
        return
    end
    local context = source_buffer()
    local generation, slot = M.generation, {}
    M.operations[slot] = true
    if writing_kinds[kind] then
        M.writer = slot
    end
    local completed = false
    local function done(call_err, result)
        if completed then
            return
        end
        completed = true
        M.operations[slot] = nil
        if M.writer == slot then
            M.writer = nil
        end
        if generation ~= M.generation then
            if callback then
                callback(call_err or 'cancelled', result)
            end
            return
        end
        if callback then
            callback(call_err, result)
        else
            local text = call_err and ('Error: ' .. tostring(call_err))
                or (type(result) == 'string' and result or vim.inspect(result))
            require('ai.rose.ui').append(kind, text)
        end
    end
    local started, token = pcall(start, done, context)
    if not started then
        done(tostring(token))
        return
    end
    slot.token = token
    return token
end

---@param text string?
---@param callback fun(err: string?, answer: string?)?
---@return table? token
function M.ask(text, callback)
    if not text then
        prompt(nil, 'RoseAsk', function(value)
            M.ask(value, callback)
        end)
        return
    end
    return operation('Ask', callback, function(done)
        if type(text) ~= 'string' or text:match('^%s*$') then
            done('question must not be empty')
            return
        end
        if M.ask_pending then
            done('a chat request is already running; use :RoseStop first')
            return
        end
        M.ask_pending = true
        local messages = vim.deepcopy(M.chat_history or {
            {
                role = 'system',
                content = 'You are Rose, a coding assistant. Answer honestly. '
                    .. 'This chat has no tools; do '
                    .. 'not claim you edited files or ran checks.',
            },
        })
        messages[#messages + 1] = { role = 'user', content = text }
        while #vim.json.encode(messages) > M.options.agent.max_context and #messages > 2 do
            table.remove(messages, 2)
        end
        if #vim.json.encode(messages) > M.options.agent.max_context then
            M.ask_pending = false
            done('chat context size limit exceeded')
            return
        end
        if not callback then
            require('ai.rose.ui').append('You', text)
        end
        local generation = M.generation
        return require('ai.rose.model').chat(M.options, messages, nil, function(err, message)
            if generation == M.generation then
                M.ask_pending = false
            end
            if not err and (not message or type(message.content) ~= 'string' or message.content == '') then
                err = 'Model returned no chat text (RoseAsk does not execute tools)'
            end
            if not err and generation == M.generation then
                -- Opaque provider replay metadata stays private in memory; never print it.
                local assistant = vim.deepcopy(message)
                assistant.role = 'assistant'
                messages[#messages + 1] = assistant
                M.chat_history = messages
            end
            done(err, message and message.content)
        end)
    end)
end

---@param task string?
---@param callback fun(err: string?, report: table?)?
---@return table? token
function M.agent(task, callback)
    if not task then
        prompt(nil, 'RoseAgent', function(value)
            M.agent(value, callback)
        end)
        return
    end
    return operation('Agent', callback, function(done, context)
        if M.tool_error then
            done(M.tool_error)
            return
        end
        if not callback then
            require('ai.rose.ui').append('Task', task)
        end
        return require('ai.rose.agent').run(M.options, task, done, {
            context_buf = context,
            on_event = not callback and function(event)
                require('ai.rose.ui').append('Agent', event)
            end or nil,
        })
    end)
end

-- ---------------------------------------------------------------------------
-- Plan/generate entry points for the builder (ai.builder).
-- ---------------------------------------------------------------------------
-- Thin bounded wrappers over agent.run. Both inject the read-only tool
-- module, so the model can inspect the workspace but can never write
-- files before the user confirms them in the builder. Iterations are
-- bounded by the agent config (opts may only tighten them); a wall-clock
-- timeout cancels the run. When no model/provider is configured, setup
-- fails inside operation() and the callback receives the error -- output
-- is never invented.

local PLAN_TIMEOUT_MS = 300000
local GENERATE_TIMEOUT_MS = 600000
local PROMPT_SPEC_LEN_MAX = 4000
local PLAN_TEXT_LEN_MAX = 32768
local FILE_BLOCK_COUNT_MAX = 64
local FILE_CONTENT_BYTES_MAX = 262144
local BLOCK_PATH_LEN_MAX = 256

---@class AiRosePlanOpts
---@field spec table Builder spec; spec.name must be a non-empty string.
---@field timeout_ms integer? Wall-clock budget; defaults to 300000.
---@field max_iterations integer? Tightens the agent iteration cap; never raised.
---@field max_repair_rounds integer? Tightens the repair-round cap; never raised.
---@field backend function? Test/provider injection, forwarded to agent.run.
---@field on_event fun(text: string)? Progress events.

---@class AiRoseGenerateOpts
---@field spec table Builder spec; spec.name must be a non-empty string.
---@field plan string Approved plan text.
---@field timeout_ms integer? Wall-clock budget; defaults to 600000.
---@field max_iterations integer? Tightens the agent iteration cap; never raised.
---@field max_repair_rounds integer? Tightens the repair-round cap; never raised.
---@field backend function? Test/provider injection, forwarded to agent.run.
---@field on_event fun(text: string)? Progress events.

---@class AiRoseFile
---@field path string Relative path; no traversal, no absolute paths.
---@field content string Full file content.

---Render the caller-supplied spec into bounded prompt text.
---@param spec any
---@return string? text
---@return string? err
local function render_spec(spec)
    if type(spec) ~= 'table' then
        return nil, 'spec must be a table'
    end
    if type(spec.name) ~= 'string' or spec.name:match('^%s*$') then
        return nil, 'spec.name must be a non-empty string'
    end
    local lines = {
        'Project: ' .. spec.name,
        'Type: ' .. tostring(spec.project_type or 'unspecified'),
        'Language: ' .. tostring(spec.language or 'unspecified'),
    }
    if type(spec.features) == 'table' and #spec.features > 0 then
        local features = {}
        for _, feature in ipairs(spec.features) do
            features[#features + 1] = tostring(feature)
        end
        lines[#lines + 1] = 'Features: ' .. table.concat(features, ', ')
    end
    if type(spec.write_in) == 'string' and not spec.write_in:match('^%s*$') then
        lines[#lines + 1] = 'Notes: ' .. spec.write_in
    end
    if type(spec.style_note) == 'string' and spec.style_note ~= '' then
        lines[#lines + 1] = spec.style_note
    end
    local text = table.concat(lines, '\n')
    if #text > PROMPT_SPEC_LEN_MAX then
        return nil, 'spec rendering exceeds length bound'
    end
    return text
end

---Derive the agent config for a run: a copy of the resolved config with
---iteration caps optionally tightened. The shared config is never mutated.
---@param base table Resolved Rose config.
---@param opts table Caller opts.
---@return table? config
---@return string? err
local function derive_config(base, opts)
    assert(type(base) == 'table', 'derive_config: base config must be a table')
    local max_iterations, max_repair_rounds = opts.max_iterations, opts.max_repair_rounds
    if max_iterations == nil and max_repair_rounds == nil then
        return base
    end
    if max_iterations ~= nil then
        if type(max_iterations) ~= 'number' or max_iterations < 1 or max_iterations ~= math.floor(max_iterations) then
            return nil, 'max_iterations must be a positive integer'
        end
    end
    if max_repair_rounds ~= nil then
        if
            type(max_repair_rounds) ~= 'number'
            or max_repair_rounds < 0
            or max_repair_rounds ~= math.floor(max_repair_rounds)
        then
            return nil, 'max_repair_rounds must be a non-negative integer'
        end
    end
    local config = vim.deepcopy(base)
    if max_iterations ~= nil then
        config.agent.max_iterations = math.min(max_iterations, base.agent.max_iterations)
    end
    if max_repair_rounds ~= nil then
        config.agent.max_repair_rounds = math.min(max_repair_rounds, base.agent.max_repair_rounds)
    end
    return config
end

---Resolve the wall-clock budget for a run.
---@param kind string 'plan' or 'generate'.
---@param timeout_ms any
---@return integer? ms
---@return string? err
local function check_timeout(kind, timeout_ms)
    assert(kind == 'plan' or kind == 'generate', 'check_timeout: unknown kind')
    if timeout_ms == nil then
        return kind == 'plan' and PLAN_TIMEOUT_MS or GENERATE_TIMEOUT_MS
    end
    if type(timeout_ms) ~= 'number' or timeout_ms <= 0 or timeout_ms ~= math.floor(timeout_ms) then
        return nil, 'timeout_ms must be a positive integer'
    end
    return timeout_ms
end

---Validate the spec, derive the bounded config and load the read-only
---tools. Failures are reported through done; nothing is raised.
---@param kind string 'plan' or 'generate'.
---@param opts table Caller opts.
---@param done fun(err: string?, result: any?)
---@return string? spec_text
---@return table? config
---@return table? tools
local function prepare_run(kind, opts, done)
    local spec_text, spec_err = render_spec(opts.spec)
    if not spec_text then
        done('rose.' .. kind .. ': ' .. spec_err)
        return nil, nil, nil
    end
    local config, config_err = derive_config(M.options, opts)
    if not config then
        done('rose.' .. kind .. ': ' .. config_err)
        return nil, nil, nil
    end
    local tools_ok, tools = pcall(require, 'ai.rose.readonly_tools')
    if not tools_ok then
        done('rose.' .. kind .. ': read-only tools unavailable: ' .. tostring(tools))
        return nil, nil, nil
    end
    return spec_text, config, tools
end

---Validate one parsed file-block path: relative, bounded, no traversal.
---@param path string
---@return boolean? ok
---@return string? err
local function check_block_path(path)
    if type(path) ~= 'string' or path == '' then
        return nil, 'empty path'
    end
    if #path > BLOCK_PATH_LEN_MAX then
        return nil, 'path exceeds length bound'
    end
    if path:find('\0', 1, true) then
        return nil, 'path contains NUL byte'
    end
    if path:sub(1, 1) == '/' then
        return nil, 'absolute paths are not allowed'
    end
    if path:find('..', 1, true) then
        return nil, 'path traversal is not allowed'
    end
    return true
end

---Parse <<<FILE path="...">>> ... <<<END>>> blocks from coder output.
---A missing or malformed block set is an honest error, never invented.
---@param text string Coder output text.
---@return AiRoseFile[]? files
---@return string? err
local function parse_file_blocks(text)
    assert(type(text) == 'string', 'parse_file_blocks expects text')
    local files = {}
    local pos = 1
    while true do
        local _, header_end, path = text:find('<<<%s*FILE%s+path="([^"\n]-)"%s*>>>', pos)
        if not header_end then
            break
        end
        local body_start, body_end = text:find('<<<%s*END%s*>>>', header_end + 1)
        if not body_start then
            return nil, 'unterminated file block for path "' .. tostring(path) .. '"'
        end
        local path_ok, path_err = check_block_path(path)
        if not path_ok then
            return nil, 'invalid file block path: ' .. tostring(path_err)
        end
        local content = text:sub(header_end + 1, body_start - 1):gsub('^\n', '')
        if #content > FILE_CONTENT_BYTES_MAX then
            return nil, 'file block exceeds size bound: ' .. path
        end
        files[#files + 1] = { path = path, content = content }
        if #files > FILE_BLOCK_COUNT_MAX then
            return nil, 'too many file blocks'
        end
        pos = body_end + 1
    end
    if #files == 0 then
        return nil, 'no file blocks found in coder output'
    end
    return files
end

---Run the agent with read-only tools, a wall-clock timeout and a result
---extractor. The token supports cancellation; the timeout cancels it.
---@param kind string 'plan' or 'generate', used in messages.
---@param config table Derived agent config.
---@param task string Agent task prompt.
---@param tools table Read-only tools module.
---@param opts table Caller opts (timeout_ms, backend, on_event).
---@param context integer Source buffer for tool context.
---@param done fun(err: string?, result: any?)
---@param extract fun(report: table): any?, string?
---@return table token
local function run_bounded(kind, config, task, tools, opts, context, done, extract)
    assert(type(kind) == 'string', 'run_bounded: kind must be a string')
    assert(type(config) == 'table', 'run_bounded: config must be a table')
    assert(type(task) == 'string', 'run_bounded: task must be a string')
    assert(type(tools) == 'table', 'run_bounded: tools must be a table')
    assert(type(done) == 'function', 'run_bounded: done must be a function')
    assert(type(extract) == 'function', 'run_bounded: extract must be a function')
    if opts.backend ~= nil then
        assert(type(opts.backend) == 'function', 'run_bounded: backend must be a function')
    end
    if opts.on_event ~= nil then
        assert(type(opts.on_event) == 'function', 'run_bounded: on_event must be a function')
    end
    local timeout_ms, timeout_err = check_timeout(kind, opts.timeout_ms)
    if not timeout_ms then
        done('rose.' .. kind .. ': ' .. timeout_err)
        return nil
    end
    local finished, timer = false, nil
    local function finish(err, report)
        if finished then
            return
        end
        finished = true
        if timer then
            timer:close()
            timer = nil
        end
        if err ~= nil then
            done(tostring(err))
            return
        end
        local extract_ok, result, extract_err = pcall(extract, report)
        if not extract_ok then
            done('rose.' .. kind .. ': result extraction failed: ' .. tostring(result))
            return
        end
        if result == nil then
            done('rose.' .. kind .. ': ' .. tostring(extract_err or 'no result'))
            return
        end
        done(nil, result)
    end
    local token = require('ai.rose.agent').run(config, task, finish, {
        context_buf = context,
        tools = tools,
        backend = opts.backend,
        on_event = opts.on_event,
    })
    timer = vim.defer_fn(function()
        timer = nil
        if not finished then
            finished = true
            pcall(function()
                token.cancel()
            end)
            done('rose.' .. kind .. ': timed out after ' .. tostring(timeout_ms) .. ' ms')
        end
    end, timeout_ms)
    return token
end

---Plan a build: bounded agent run with read-only tools, returning the
---planner's text. Never writes files; unconfigured backends fail cleanly.
---@param opts AiRosePlanOpts
---@param callback fun(err: string?, plan: string?)
---@return table? token
function M.plan(opts, callback)
    assert(type(opts) == 'table', 'rose.plan: opts must be a table')
    assert(type(callback) == 'function', 'rose.plan: callback must be a function')
    return operation('Agent', callback, function(done, context)
        local spec_text, config, tools = prepare_run('plan', opts, done)
        if not spec_text then
            return
        end
        local task = 'Produce a build plan for the project below. Output ONLY the plan as plain text: '
            .. 'components, files to create (relative paths), and build order. Do not write any files.\n\n'
            .. spec_text
        return run_bounded('plan', config, task, tools, opts, context, done, function(report)
            local planner = type(report) == 'table' and report.roles and report.roles.planner
            if
                type(planner) ~= 'table'
                or planner.status ~= 'ok'
                or type(planner.text) ~= 'string'
                or planner.text:match('^%s*$')
            then
                return nil, 'planner produced no plan text'
            end
            return planner.text
        end)
    end)
end

---Generate application files from a spec and an approved plan: bounded
---agent run with read-only tools; file contents are parsed from the
---coder's <<<FILE>>> blocks. Never writes files; unconfigured backends
---fail cleanly.
---@param opts AiRoseGenerateOpts
---@param callback fun(err: string?, files: AiRoseFile[]?)
---@return table? token
function M.generate(opts, callback)
    assert(type(opts) == 'table', 'rose.generate: opts must be a table')
    assert(type(callback) == 'function', 'rose.generate: callback must be a function')
    return operation('Agent', callback, function(done, context)
        local spec_text, config, tools = prepare_run('generate', opts, done)
        if not spec_text then
            return
        end
        if type(opts.plan) ~= 'string' or opts.plan:match('^%s*$') then
            done('rose.generate: plan must be a non-empty string')
            return
        end
        if #opts.plan > PLAN_TEXT_LEN_MAX then
            done('rose.generate: plan exceeds length bound')
            return
        end
        local task = 'Implement the approved plan below. You have READ-ONLY tools: inspect the workspace '
            .. 'but never write files.\n\n'
            .. 'Return the COMPLETE content of EVERY file in file blocks with EXACTLY this shape:\n'
            .. '<<<FILE path="relative/path.ext">>>\n<full file content>\n<<<END>>>\n\n'
            .. 'Rules: one block per file; paths relative to the project root, no "..", no absolute paths; '
            .. 'never emit <<<END>>> inside file content; complete working code, no placeholders. '
            .. 'Output ONLY the file blocks.\n\nProject:\n'
            .. spec_text
            .. '\n\nApproved plan:\n'
            .. opts.plan
        return run_bounded('generate', config, task, tools, opts, context, done, function(report)
            local coder = type(report) == 'table' and report.roles and report.roles.coder
            if type(coder) ~= 'table' or type(coder.text) ~= 'string' then
                return nil, 'coder produced no output text'
            end
            return parse_file_blocks(coder.text)
        end)
    end)
end

---@param name string?
---@param callback fun(err: string?, report: table?)?
---@return table? token
function M.check(name, callback)
    return operation('Check', callback, function(done, context)
        if M.tool_error then
            done(M.tool_error)
            return
        end
        return require('ai.rose.validation').run(M.options, require('ai.rose.tools'), name, done, context)
    end)
end

---@param task string?
---@param callback fun(err: string?, result: table?)?
---@return table? token
function M.flow(task, callback)
    if not task then
        prompt(nil, 'RoseFlow', function(value)
            M.flow(value, callback)
        end)
        return
    end
    return operation('Flow', callback, function(done, context)
        if M.tool_error and M.options.flow.bridge ~= false then
            done(M.tool_error)
            return
        end
        -- Keep a real project buffer active when Flow first attaches. Native Rose
        -- tools use explicit captured buffers; Flow captures editor_context itself.
        if context and vim.api.nvim_buf_is_valid(context) then
            local window = vim.fn.bufwinid(context)
            if window ~= -1 then
                vim.api.nvim_set_current_win(window)
            end
        end
        if not callback then
            require('ai.rose.ui').append('Flow task', task)
        end
        return require('ai.rose.flow').call('flow_run', { task = task }, done)
    end)
end

---@param server_name string
---@param tool_name string
---@param args table
---@param callback fun(err: string?, result: table?)
---@return table? token
function M.mcp(server_name, tool_name, args, callback)
    assert(type(callback) == 'function', 'mcp requires callback(err, result)')
    return operation('MCP', callback, function(done)
        return require('ai.rose.servers').call(server_name, tool_name, args, done)
    end)
end

---@param request table raw provider JSON request spec
---@param callback fun(err: string?, result: table?)
---@return table? token
function M.model_request(request, callback)
    assert(type(callback) == 'function', 'model_request requires callback(err, result)')
    return operation('Model API', callback, function(done)
        return require('ai.rose.model').request(M.options, request, done)
    end)
end

-- Cancel every tracked operation, then stop the owned transports and bridges.
--- Cancel every tracked operation, then stop owned transports.
function M.stop()
    local slots = {}
    for slot in pairs(M.operations) do
        slots[#slots + 1] = slot
    end
    for _, slot in ipairs(slots) do
        if slot.token and slot.token.cancel then
            pcall(slot.token.cancel)
        end
    end
    -- Tokens complete only when their execution fence is satisfied. In particular,
    -- Flow keeps the writer slot until its process has actually exited.
    M.ask_pending = false
    for _, name in ipairs({
        'ai.rose.http',
        'ai.rose.servers',
        'ai.rose.flow',
        'ai.rose.mcp',
        'ai.rose.model',
    }) do
        local module = package.loaded[name]
        if module and module.stop then
            pcall(module.stop)
        end
    end
end

--- Cancel everything, delete commands and reset setup state.
function M.shutdown()
    M.generation = M.generation + 1
    M.stop()
    local ui = package.loaded['ai.rose.ui']
    if ui then
        ui.close()
    end
    for _, name in ipairs(require('ai.rose.commands').names) do
        pcall(vim.api.nvim_del_user_command, name)
    end
    pcall(vim.api.nvim_del_augroup_by_name, 'RoseNative')
    M.did_setup, M.context_buf, M.chat_history = false, nil, nil
end

-- Register the Rose* user commands idempotently.
--- Register the Rose* user commands idempotently.
function M.register_commands()
    require('ai.rose.commands').register(M)
end

-- Optional modules record their failure instead of aborting setup so
-- :checkhealth can report it.
---@param config table resolved Rose config
local function setup_optional_modules(config)
    assert(type(config) == 'table', 'setup_optional_modules: config must be a table')
    M.tool_error = nil
    local tools_ok, tools = pcall(require, 'ai.rose.tools')
    if tools_ok and type(tools.setup) == 'function' then
        local setup_ok, setup_err = pcall(tools.setup, {
            workspace = config.workspace,
            trusted = config.trusted,
            checks = config.checks,
        })
        if not setup_ok then
            M.tool_error = 'native tools setup failed: ' .. tostring(setup_err)
        end
    else
        M.tool_error = 'native tools unavailable: ' .. tostring(tools)
    end
    require('ai.rose.flow').setup(config)
    require('ai.rose.servers').setup(config)
    require('ai.rose.ui').setup({
        on_stop = M.stop,
        on_ask = M.ask,
    })
end

---@param config table
---@param router table?
local function notify_setup_warnings(config, router)
    if router then
        local info = router.describe(config)
        if info.cloud then
            vim.notify(
                'Rose cloud mode: tasks, source context and tool output will leave this device '
                    .. 'for the explicitly configured '
                    .. info.provider
                    .. ' endpoint.',
                vim.log.levels.WARN
            )
        end
    end
    if type(vim.system) ~= 'function' then
        vim.notify(
            'Rose: vim.system unavailable; chat/MCP/checks require Neovim 0.10+. ' .. 'Native UI remains available.',
            vim.log.levels.WARN
        )
    end
end

---Configure native Rose.
---@param opts? table Partial native options; omitted fields retain defaults.
---@return table? self
---@return string? err
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'Rose setup options must be a table')
    if M.did_setup then
        return M
    end
    local config_ok, config = pcall(require('ai.rose.config').resolve, opts)
    if not config_ok then
        notify_error(config)
        return nil, tostring(config)
    end
    local router_ok, router = pcall(require, 'ai.rose.model')
    if router_ok then
        local valid, why = router.validate(config)
        if not valid then
            notify_error(why)
            return nil, why
        end
    elseif config.providers.provider ~= 'ollama' then
        local why = 'cloud provider router unavailable'
        notify_error(why)
        return nil, why
    end
    M.shutdown()
    M.options = config
    setup_optional_modules(config)
    M.register_commands()
    local group = vim.api.nvim_create_augroup('RoseNative', { clear = true })
    vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.shutdown })
    M.did_setup = true
    notify_setup_warnings(config, router_ok and router or nil)
    assert(M.options == config, 'setup must publish the resolved config')
    return M
end

-- Historical binary helpers do not load binary/build modules in native mode.
---@return boolean
function M.rose_check()
    return false
end

---@return nil
function M.get_binary_path()
    return nil
end

return M
