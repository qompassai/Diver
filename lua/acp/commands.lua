-- Native commands; captures bind delayed UI actions to the original conversation.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local api = vim.api
local config, context, session, ui, util =
    require('acp.config'),
    require('acp.context'),
    require('acp.session'),
    require('acp.ui'),
    require('acp.util')
local M = {}
local owned = {}

local function report(_, err)
    if err then
        util.notify(err, vim.log.levels.ERROR)
    end
end

function M.current()
    return session.get(vim.b.acp_session)
end

local function current()
    local state = M.current()
    if not state then
        util.notify('Use :AcpStart to select a configured agent')
    end
    return state
end

local function checked(ok, err)
    if not ok then
        report(nil, err)
    end
end

function M.start(name, options)
    local state, err = session.create(name, options and options.cwd)
    if not state then
        report(nil, err)
        return nil, err
    end
    ui.open(state)
    checked(session.discover(state, report))
    return state
end

local function pick_agent()
    vim.ui.select(config.names(), { prompt = 'Configured agent' }, function(name)
        if name then
            M.start(name)
        end
    end)
end

local function send(state, parts, review)
    local function submit()
        checked(session.send(state, parts, report))
    end
    if not review then
        submit()
        return
    end
    local generation = state.generation
    local payload = {}
    for _, part in ipairs(parts) do
        payload[#payload + 1] = part.text
    end
    checked(
        require('acp.permissions').confirm(
            'Send context to ' .. state.agent_name .. ' at ' .. state.agent.url,
            table.concat(payload, '\n\n'),
            function(allowed)
                if
                    allowed
                    and not state.closed
                    and not state.busy
                    and state.generation == generation
                then
                    submit()
                end
            end
        )
    )
end

local function prompt(command)
    local state = current()
    if not state then
        return
    end
    if command.args ~= '' then
        send(state, { { text = command.args } })
        return
    end
    vim.ui.input({ prompt = 'Prompt ' .. state.agent_name .. ': ' }, function(value)
        if value and value ~= '' then
            send(state, { { text = value } })
        end
    end)
end

local function buffer_prompt(command)
    local state = current()
    if not state then
        return
    end
    local buf = api.nvim_get_current_buf()
    local name = api.nvim_buf_get_name(buf)
    if
        vim.bo[buf].buftype ~= ''
        or not util.absolute(name)
        or not util.contains(state.cwd, name)
    then
        util.notify('Select a source buffer in this conversation workspace')
        return
    end
    local first = command.range > 0 and command.line1 - 1 or 0
    local last = command.range > 0 and command.line2 or api.nvim_buf_line_count(buf)
    if last - first > 10000 then
        util.notify('Selection exceeds 10000 lines')
        return
    end
    local text = table.concat(api.nvim_buf_get_lines(buf, first, last, false), '\n')
    if #text > 524288 then
        util.notify('Selection exceeds 512 KiB')
        return
    end
    local label = vim.fs.relpath(state.cwd, name) or vim.fs.basename(name)
    vim.ui.input({ prompt = 'Instruction for selected source: ' }, function(value)
        if not value or value == '' then
            return
        end
        send(state, { { text = value }, { text = label .. '\n\n' .. text } }, true)
    end)
end

local function context_send()
    local state = current()
    if not state then
        return
    end
    local paths, err = context.list(state.cwd)
    if not paths then
        report(nil, err)
        return
    end
    vim.ui.select(paths, { prompt = 'Select project context to send' }, function(path)
        if not path then
            return
        end
        local parts, failure = context.attach(state.cwd, { path })
        if not parts then
            report(nil, failure)
            return
        end
        send(state, parts, true)
    end)
end

local function context_command()
    local state = current()
    if not state then
        return
    end
    local commands, err = context.commands(state.cwd)
    if not commands then
        report(nil, err)
        return
    end
    vim.ui.select(commands, {
        prompt = 'Context command document',
        format_item = function(item)
            return '@' .. item.name
        end,
    }, function(item)
        if not item then
            return
        end
        vim.ui.input({ prompt = 'Command arguments: ' }, function(value)
            if value == nil then
                return
            end
            local parts, failure = context.command_blocks(state.cwd, item.name, value)
            if not parts then
                report(nil, failure)
                return
            end
            send(state, parts, true)
        end)
    end)
end

local function inspect_operation(operation, params)
    local state = current()
    if not state then
        return
    end
    checked(session.inspect(state, operation, params or {}, function(value, err)
        if err then
            report(nil, err)
            return
        end
        ui.inspect(operation .. ' — ' .. state.agent_name, value)
    end))
end

local function with_state(callback)
    return function(command)
        local state = current()
        if state then
            callback(state, command)
        end
    end
end

local function resume(state, command)
    if state.agent.protocol ~= 'acp-communication' then
        util.notify('A2A input-required tasks continue with :AcpPrompt')
        return
    end
    local value, err = util.decode(command.args)
    if not value then
        report(nil, err)
        return
    end
    checked(session.send(state, { { text = 'Resume awaiting run' } }, report, value))
end

local function sessions()
    local values = vim.tbl_values(session.sessions)
    table.sort(values, function(a, b)
        return a.key < b.key
    end)
    vim.ui.select(values, {
        prompt = 'Local conversation',
        format_item = function(item)
            return item.agent_name .. ' ' .. item.key
        end,
    }, function(state)
        if state and not state.closed then
            session.current = state.key
            ui.open(state)
        end
    end)
end

local function history()
    vim.ui.select(
        require('acp.store').list(),
        { prompt = 'Saved conversation (read-only)' },
        function(path)
            if not path then
                return
            end
            local data, err = require('acp.store').read(path)
            if not data then
                report(nil, err)
                return
            end
            ui.inspect('Saved conversation', data)
        end
    )
end

function M.setup()
    M.teardown()
    local commands = {
        AcpAgents = { pick_agent },
        AcpBuffer = { buffer_prompt, { range = true } },
        AcpCancel = {
            with_state(function(state)
                checked(session.cancel(state, report))
            end),
        },
        AcpCard = {
            with_state(function(state)
                ui.inspect('Agent Card / manifest', state.peer or {})
            end),
        },
        AcpClose = { with_state(function(state)
            session.close(state)
        end) },
        AcpContextBrowse = {
            function()
                context.browse(context.root())
            end,
        },
        AcpContextCli = {
            function(cmd)
                checked(context.cli(cmd.fargs))
            end,
            { nargs = '*' },
        },
        AcpContextCommand = { context_command },
        AcpContextScaffold = {
            function()
                checked(context.scaffold())
            end,
        },
        AcpContextSend = { context_send },
        AcpDelegate = { with_state(require('acp.delegate').select) },
        AcpDiscover = {
            with_state(function(state)
                checked(session.discover(state, report))
            end),
        },
        AcpEvents = {
            with_state(function(state)
                inspect_operation('events', { id = state.remote.id })
            end),
        },
        AcpExtendedCard = {
            function()
                inspect_operation('extended')
            end,
        },
        AcpHistory = { history },
        AcpNew = { pick_agent },
        AcpOpen = { with_state(ui.open) },
        AcpPrompt = { prompt, { nargs = '?' } },
        AcpRefresh = {
            with_state(function(state)
                checked(session.refresh(state, report))
            end),
        },
        AcpResume = { with_state(resume), { nargs = 1 } },
        AcpSelection = { buffer_prompt, { range = true } },
        AcpSessions = { sessions },
        AcpStart = {
            function(cmd)
                if cmd.args == '' then
                    pick_agent()
                else
                    M.start(cmd.args)
                end
            end,
            {
                nargs = '?',
                complete = function()
                    return config.names()
                end,
            },
        },
        AcpStatus = {
            with_state(function(state)
                ui.inspect('Agent status', {
                    agent = state.agent_name,
                    protocol = state.agent.protocol,
                    busy = state.busy,
                    error = state.error,
                    remote = state.remote,
                    delegation = state.delegation,
                })
            end),
        },
        AcpStop = { with_state(function(state)
            session.close(state)
        end) },
        AcpSubscribe = {
            with_state(function(state)
                checked(session.subscribe(state, report))
            end),
        },
        AcpTasks = {
            function(cmd)
                inspect_operation(
                    'list',
                    { pageSize = 50, pageToken = cmd.args, historyLength = 0 }
                )
            end,
            { nargs = '?' },
        },
        AcpWire = {
            with_state(function(state)
                ui.inspect('Bounded received wire records', state.wire)
            end),
        },
    }
    local names = vim.tbl_keys(commands)
    table.sort(names)
    for _, name in ipairs(names) do
        if vim.fn.exists(':' .. name) == 2 then
            util.notify(
                'Existing command preserved: ' .. name .. '; remove old ACP setup and restart'
            )
        else
            local item = commands[name]
            local opts = vim.tbl_extend('force', { desc = 'Diver agent: ' .. name }, item[2] or {})
            api.nvim_create_user_command(name, item[1], opts)
            owned[#owned + 1] = name
        end
    end
end

function M.teardown()
    for _, name in ipairs(owned) do
        api.nvim_del_user_command(name)
    end
    owned = {}
end
return M
