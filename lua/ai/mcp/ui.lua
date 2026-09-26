-- /qompassai/Diver/lua/ai/mcp/ui.lua
-- Qompass AI MCP Server Browser (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Floating-window browser over registered MCP servers and their tools,
-- in the style of ai.a2a.ui: one buffer per view, `q` closes, `<CR>`
-- drills in. Server view: name, enabled flag, running flag, command.
-- Tool view: tool name and one-line description; `<CR>` shows the input
-- schema, `c` calls the tool (JSON args prompt, then the confirmed flow
-- in ai.mcp.tools -- never auto-executed).

local registry = require('ai.mcp.registry')
local client = require('ai.mcp.client')
local tools = require('ai.mcp.tools')

local M = {}

local SCHEMA_PREVIEW_BYTES_MAX = 4096
local CALL_RESULT_BYTES_MAX = 8192

local view = nil ---@type { buf: integer, rows: table[] }?

---@param title string
---@param lines string[]
---@return integer buf
local function open_float(title, lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'mcp://' .. title)
    vim.bo[buf].filetype = 'mcp-browser'
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
    local width = math.floor(vim.o.columns * 0.7)
    local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.6))
    height = math.max(height, 6)
    vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. title .. ' ',
    })
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    return buf
end

---@param buf integer
---@param lines string[]
local function redraw(buf, lines)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

---@param rows table[]
---@param index integer
---@return table?
local function row_at(rows, index)
    if index >= 1 and index <= #rows then
        return rows[index]
    end
    return nil
end

---@param text string
local function show_text(title, text)
    local lines = vim.split(text:sub(1, CALL_RESULT_BYTES_MAX), '\n', { plain = true })
    open_float(title, lines)
end

local function render_servers()
    assert(view ~= nil, 'server view is not open')
    local lines = { 'MCP servers  (q close, <CR> tools, e toggle, x remove)', '' }
    view.rows = {}
    for _, entry in ipairs(registry.list()) do
        local status = entry.enabled and 'on ' or 'off'
        if client.is_running(entry.name) then
            status = status .. '*'
        end
        view.rows[#view.rows + 1] = { kind = 'server', name = entry.name }
        local line = string.format('%-4s %-24s %s', status, entry.name:sub(1, 24), entry.command)
        lines[#lines + 1] = line
    end
    if #view.rows == 0 then
        lines[#lines + 1] = '(no servers registered; use :McpAdd or :McpInstall)'
    end
    redraw(view.buf, lines)
end

---@param row table
local function show_tool_schema(row)
    tools.describe(row.server, row.name, function(err, tool)
        vim.schedule(function()
            if err ~= nil then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            assert(tool ~= nil, 'describe returned no error and no tool')
            local schema = vim.json.encode(tool.input_schema)
            local body = tool.name .. '\n\n' .. schema:sub(1, SCHEMA_PREVIEW_BYTES_MAX)
            show_text('schema: ' .. tool.name, body)
        end)
    end)
end

---@param row table
local function call_tool_from_row(row)
    local args_prompt = 'Args for ' .. row.name .. ' (JSON object): '
    vim.ui.input({ prompt = args_prompt, default = '{}' }, function(input)
        if input == nil then
            return
        end
        local ok, args = pcall(vim.json.decode, input)
        if not ok or type(args) ~= 'table' then
            vim.notify('Args must be a JSON object', vim.log.levels.ERROR)
            return
        end
        tools.call(row.server, row.name, args, function(err, result)
            vim.schedule(function()
                if err ~= nil then
                    vim.notify(err, vim.log.levels.ERROR)
                    return
                end
                show_text('result: ' .. row.name, vim.json.encode(result))
            end)
        end)
    end)
end

---@param buf integer
---@param tool_rows table[]
local function wire_tool_keys(buf, tool_rows)
    vim.keymap.set('n', '<CR>', function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = row_at(tool_rows, cursor[1] - 2)
        if row ~= nil then
            show_tool_schema(row)
        end
    end, { buffer = buf, silent = true })
    vim.keymap.set('n', 'c', function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = row_at(tool_rows, cursor[1] - 2)
        if row ~= nil then
            call_tool_from_row(row)
        end
    end, { buffer = buf, silent = true })
end

---@param server_name string
local function open_tools(server_name)
    local buf = open_float('tools: ' .. server_name, { 'Loading tools...' })
    local tool_rows = {} ---@type table[]
    tools.list(server_name, function(err, listed)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            if err ~= nil then
                redraw(buf, { 'Error: ' .. err })
                return
            end
            assert(listed ~= nil, 'tools.list returned no error and no tools')
            local header = 'Tools on ' .. server_name .. '  (q close, <CR> schema, c call)'
            local lines = { header, '' }
            for _, tool in ipairs(listed) do
                local row = { kind = 'tool', server = server_name, name = tool.name }
                tool_rows[#tool_rows + 1] = row
                local desc = tool.description:gsub('\n', ' '):sub(1, 60)
                lines[#lines + 1] = string.format('%-28s %s', tool.name:sub(1, 28), desc)
            end
            if #tool_rows == 0 then
                lines[#lines + 1] = '(server exposes no tools)'
            end
            redraw(buf, lines)
        end)
    end)
    wire_tool_keys(buf, tool_rows)
end

function M.open()
    if view ~= nil and vim.api.nvim_buf_is_valid(view.buf) then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == view.buf then
                vim.api.nvim_set_current_win(win)
                render_servers()
                return
            end
        end
    end
    local buf = open_float('MCP servers', {})
    view = { buf = buf, rows = {} }
    render_servers()
    vim.keymap.set('n', '<CR>', function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = view ~= nil and row_at(view.rows, cursor[1] - 2) or nil
        if row ~= nil then
            open_tools(row.name)
        end
    end, { buffer = buf, silent = true })
    vim.keymap.set('n', 'e', function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = view ~= nil and row_at(view.rows, cursor[1] - 2) or nil
        if row == nil then
            return
        end
        local entry = registry.get(row.name)
        if entry == nil then
            return
        end
        local ok, err
        if entry.enabled then
            ok, err = registry.disable(row.name)
            client.stop(row.name)
        else
            ok, err = registry.enable(row.name)
        end
        if not ok then
            vim.notify(tostring(err), vim.log.levels.ERROR)
        end
        render_servers()
    end, { buffer = buf, silent = true })
    vim.keymap.set('n', 'x', function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = view ~= nil and row_at(view.rows, cursor[1] - 2) or nil
        if row == nil then
            return
        end
        local options = { 'Remove ' .. row.name, 'Cancel' }
        vim.ui.select(options, { prompt = 'Remove server?' }, function(choice)
            if choice == nil or not choice:match('^Remove') then
                return
            end
            client.stop(row.name)
            local ok, err = registry.remove(row.name)
            if not ok then
                vim.notify(tostring(err), vim.log.levels.ERROR)
            end
            render_servers()
        end)
    end, { buffer = buf, silent = true })
end

return M
