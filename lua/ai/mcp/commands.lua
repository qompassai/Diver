-- /qompassai/Diver/lua/ai/mcp/commands.lua
-- Qompass AI MCP User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the MCP manager: browse servers, register,
-- enable/disable and remove them, inspect and call their tools, search
-- for new servers and install them. Requiring this module registers the
-- commands; it starts nothing. Names were checked against the existing
-- Acp*/A2a* commands: no Mcp* command existed before this module.

local api = vim.api

local registry = require('ai.mcp.registry')
local client = require('ai.mcp.client')
local tools = require('ai.mcp.tools')
local ui = require('ai.mcp.ui')
local discovery = require('ai.mcp.discovery')

---@return string[]
local function complete_names()
    local names = {}
    for _, entry in ipairs(registry.list()) do
        names[#names + 1] = entry.name
    end
    return names
end

---@param name string
---@param command string
---@param args string[]
local function add_with_confirmation(name, command, args)
    ---@type McpServerEntry
    local entry = { name = name, command = command, args = args, enabled = true }
    local valid, validation_err = registry.validate(entry)
    if not valid then
        vim.notify('Invalid entry: ' .. tostring(validation_err), vim.log.levels.ERROR)
        return
    end
    local flags = registry.risk_flags(entry)
    for _, flag in ipairs(flags) do
        vim.notify('WARNING: ' .. flag, vim.log.levels.WARN)
    end
    local preview = 'Add MCP server?\n'
        .. string.format('  name:    %s\n  command: %s\n', name, command)
        .. '  args:    '
        .. vim.json.encode(args)
        .. '\nType the server name to confirm:'
    vim.ui.input({ prompt = preview }, function(typed)
        if typed ~= name then
            vim.notify('McpAdd cancelled', vim.log.levels.WARN)
            return
        end
        local ok, err = registry.add(entry)
        if not ok then
            vim.notify('McpAdd failed: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.notify('MCP server added: ' .. name, vim.log.levels.INFO)
    end)
end

local function add_interactive()
    vim.ui.input({ prompt = 'Server name: ' }, function(name)
        if name == nil or name == '' then
            return
        end
        vim.ui.input({ prompt = 'Command (absolute path): ' }, function(command)
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
                add_with_confirmation(name, command, args)
            end)
        end)
    end)
end

---@param name string
---@param item McpTool
local function prompt_and_call(name, item)
    vim.ui.input({
        prompt = 'Args for ' .. item.name .. ' (JSON object): ',
        default = '{}',
    }, function(input)
        if input == nil then
            return
        end
        local ok, args = pcall(vim.json.decode, input)
        if not ok or type(args) ~= 'table' then
            vim.notify('Args must be a JSON object', vim.log.levels.ERROR)
            return
        end
        tools.call(name, item.name, args, function(call_err, result)
            vim.schedule(function()
                if call_err ~= nil then
                    vim.notify(call_err, vim.log.levels.ERROR)
                    return
                end
                api.nvim_echo({ { vim.json.encode(result), 'Normal' } }, false, {})
            end)
        end)
    end)
end

---@param name string
---@param item McpTool
local function tool_action(name, item)
    vim.ui.select({ 'View schema', 'Call tool', 'Cancel' }, {
        prompt = item.name,
    }, function(choice)
        if choice == 'View schema' then
            local schema = vim.json.encode(item.input_schema)
            api.nvim_echo({ { item.name .. '\n' .. schema, 'Normal' } }, false, {})
        elseif choice == 'Call tool' then
            prompt_and_call(name, item)
        end
    end)
end

---@param name string
local function pick_tool(name)
    tools.list(name, function(err, listed)
        vim.schedule(function()
            if err ~= nil then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            assert(listed ~= nil, 'tools.list returned no error and no tools')
            vim.ui.select(listed, {
                prompt = 'Tools on ' .. name .. ':',
                format_item = function(item)
                    return item.name
                end,
            }, function(item)
                if item ~= nil then
                    tool_action(name, item)
                end
            end)
        end)
    end)
end

---@param server_name string?
local function tools_menu(server_name)
    if server_name ~= nil and server_name ~= '' then
        pick_tool(server_name)
        return
    end
    local entries = registry.list()
    if #entries == 0 then
        vim.notify('No MCP servers registered', vim.log.levels.WARN)
        return
    end
    vim.ui.select(entries, {
        prompt = 'MCP server:',
        format_item = function(item)
            return item.name .. (item.enabled and '' or ' (disabled)')
        end,
    }, function(item)
        if item ~= nil then
            pick_tool(item.name)
        end
    end)
end

api.nvim_create_user_command('McpServers', function()
    ui.open()
end, { desc = 'Browse registered MCP servers' })

api.nvim_create_user_command('McpAdd', function(command)
    local fargs = command.fargs
    if #fargs < 2 then
        add_interactive()
        return
    end
    -- :McpAdd <name> <command> [args...] -- each farg is one argv element,
    -- never a shell string.
    local args = {}
    for index = 3, #fargs do
        args[#args + 1] = fargs[index]
    end
    add_with_confirmation(fargs[1], fargs[2], args)
end, {
    nargs = '*',
    desc = 'Add an MCP server: :McpAdd <name> <absolute-command> [args...]',
})

api.nvim_create_user_command('McpRemove', function(command)
    local name = command.args
    local options = { 'Remove ' .. name, 'Cancel' }
    vim.ui.select(options, { prompt = 'Remove MCP server?' }, function(choice)
        if choice == nil or not choice:match('^Remove') then
            return
        end
        client.stop(name)
        local ok, err = registry.remove(name)
        if not ok then
            vim.notify('McpRemove failed: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.notify('MCP server removed: ' .. name, vim.log.levels.INFO)
    end)
end, {
    nargs = 1,
    complete = complete_names,
    desc = 'Remove an MCP server (stops it first)',
})

api.nvim_create_user_command('McpEnable', function(command)
    local ok, err = registry.enable(command.args)
    if not ok then
        vim.notify('McpEnable failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    vim.notify('MCP server enabled: ' .. command.args, vim.log.levels.INFO)
end, {
    nargs = 1,
    complete = complete_names,
    desc = 'Enable an MCP server',
})

api.nvim_create_user_command('McpDisable', function(command)
    local ok, err = registry.disable(command.args)
    if not ok then
        vim.notify('McpDisable failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    client.stop(command.args)
    vim.notify('MCP server disabled and stopped: ' .. command.args, vim.log.levels.INFO)
end, {
    nargs = 1,
    complete = complete_names,
    desc = 'Disable an MCP server (stops it)',
})

api.nvim_create_user_command('McpTools', function(command)
    tools_menu(command.args ~= '' and command.args or nil)
end, {
    nargs = '?',
    complete = complete_names,
    desc = 'Inspect and call tools on an MCP server',
})

api.nvim_create_user_command('McpSearch', function(command)
    discovery.search_menu(command.args)
end, {
    nargs = '+',
    desc = 'Search for MCP servers (SearXNG first, Brave fallback)',
})

api.nvim_create_user_command('McpInstall', function(command)
    discovery.install_menu(command.args)
end, {
    nargs = '+',
    desc = 'Search for MCP servers and install one (confirmed)',
})

return true
