-- lua/dev/apps/commands.lua
-- Qompass AI Diver Dev Apps Commands
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------------------------------------------
-- User commands for dev.apps. Kept separate so init.lua stays about
-- launching; this file is about discoverability: :Apps with cmdline
-- completion and a picker, :AppsInfo showing resolved config, :AppsClose.
-- ----------------------------------------------------------------------------

local M = {}

local api = vim.api

---@param apps table dev.apps module (passed in; avoids a require cycle)
---@param arglead string
---@return string[]
local function complete_names(apps, arglead)
    local matches = {}
    for _, name in ipairs(apps.list()) do
        if name:sub(1, #arglead) == arglead then
            matches[#matches + 1] = name
        end
    end
    return matches
end

--- Scratch float showing an app's resolved configuration (:AppsInfo).
---@param info table result of apps.info()
local function show_info(info)
    local lines = {
        'app:  ' .. info.name,
        'desc: ' .. info.desc,
        'cmd:  ' .. table.concat(info.cmd, ' '),
        'kind: ' .. info.kind,
        'ctx:  ' .. info.ctx,
        'cwd:  ' .. info.cwd,
        'open: ' .. tostring(info.open),
    }
    if info.env ~= nil then
        local keys = {}
        for k in pairs(info.env) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            lines[#lines + 1] = string.format('env:  %s=%s', k, tostring(info.env[k]))
        end
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Add or override apps via require("dev.apps").setup({ apps = { ... } })'
    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, #line)
    end
    width = math.min(width + 4, math.floor(vim.o.columns * 0.9))
    local height = #lines + 2
    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' devapps ',
        title_pos = 'center',
    })
    api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>close<cr>', { silent = true, nowait = true })
    api.nvim_buf_set_keymap(bufnr, 'n', '<esc>', '<cmd>close<cr>', { silent = true, nowait = true })
end

--- Fuzzy-pick an app when :Apps gets no argument.
---@param apps table dev.apps module
local function pick_app(apps)
    local items = {}
    for _, name in ipairs(apps.list()) do
        local info = apps.info(name)
        items[#items + 1] = { name = name, desc = info.desc }
    end
    vim.ui.select(items, {
        prompt = 'Open app:',
        format_item = function(item)
            return string.format('%-12s %s', item.name, item.desc)
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        local bufnr, err = apps.open(choice.name)
        if bufnr == nil then
            vim.notify(err or 'failed to open app', vim.log.levels.ERROR)
        end
    end)
end

---@param apps table dev.apps module
function M.register(apps)
    api.nvim_create_user_command('Apps', function(cmd_opts)
        if cmd_opts.args == '' then
            pick_app(apps)
        else
            local bufnr, err = apps.open(cmd_opts.args)
            if bufnr == nil then
                vim.notify(err or 'failed to open app', vim.log.levels.ERROR)
            end
        end
    end, {
        nargs = '?',
        complete = function(arglead)
            return complete_names(apps, arglead)
        end,
        desc = 'Open an interactive CLI/TUI app (no args: pick from the catalog)',
    })

    api.nvim_create_user_command('AppsInfo', function(cmd_opts)
        local info = apps.info(cmd_opts.args)
        if info == nil then
            vim.notify(string.format("unknown app '%s'", cmd_opts.args), vim.log.levels.ERROR)
            return
        end
        show_info(info)
    end, {
        nargs = 1,
        complete = function(arglead)
            return complete_names(apps, arglead)
        end,
        desc = 'Show resolved config for a catalog app',
    })

    api.nvim_create_user_command('AppsClose', function(cmd_opts)
        if cmd_opts.args == '' then
            for _, name in ipairs(apps.list()) do
                apps.close(name)
            end
        else
            apps.close(cmd_opts.args)
        end
    end, {
        nargs = '?',
        complete = function(arglead)
            return complete_names(apps, arglead)
        end,
        desc = 'Close app terminals (no args: close all)',
    })
end

return M
