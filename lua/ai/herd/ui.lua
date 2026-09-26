-- /qompassai/Diver/lua/ai/herd/ui.lua
-- Qompass AI Herd Dashboard (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Floating window listing the persistent agents managed by ai.herd:
-- one row per agent as name | cli | machine | status | task. Rows sort
-- blocked first, then working, idle, dead, unknown; ties break by
-- name. Tasks truncate to 40 display characters and the listing caps
-- at 200 rows.
--
-- Keymaps (buffer-local, silent): <CR> jumps to the agent's tmux pane,
-- p prompts the agent, k kills it after a Yes/No confirm, r refreshes,
-- q closes.
--
-- Load-cycle note: ai.herd is required lazily inside functions. The
-- coordinator wires ai.herd -> commands -> ui, so a top-level require
-- here would create a module cycle.

local M = {}

local NAME_WIDTH_MAX = 24
local CLI_WIDTH_MAX = 16
local MACHINE_WIDTH_MAX = 16
local STATUS_WIDTH_MAX = 8
local TASK_DISPLAY_MAX = 40
local ROWS_DISPLAY_MAX = 200
local HEADER_LINE_COUNT = 3
local WINDOW_WIDTH_MAX = 112
local WINDOW_WIDTH_RATIO = 0.9
local WINDOW_HEIGHT_RATIO = 0.8
local WINDOW_HEIGHT_MIN = 6
local TMUX_TIMEOUT_MS = 5000

---@class HerdAgent
---@field name string Agent identity; also its tmux session name.
---@field cli string CLI driving the agent (e.g. 'codex', 'claude').
---@field machine string 'local' or an ssh target; '?' when unset.
---@field status string One of blocked|working|idle|dead|unknown.
---@field task string Current task, truncated to TASK_DISPLAY_MAX.

local STATUS_ORDER = {
    blocked = 1,
    working = 2,
    idle = 3,
    dead = 4,
    unknown = 5,
}

local ROW_FORMAT = string.format(
    '%%-%d.%ds | %%-%d.%ds | %%-%d.%ds | %%-%d.%ds | %%s',
    NAME_WIDTH_MAX,
    NAME_WIDTH_MAX,
    CLI_WIDTH_MAX,
    CLI_WIDTH_MAX,
    MACHINE_WIDTH_MAX,
    MACHINE_WIDTH_MAX,
    STATUS_WIDTH_MAX,
    STATUS_WIDTH_MAX
)

local win = nil ---@type integer?
local buf = nil ---@type integer?
local rows = {} ---@type HerdAgent[]

---Require ai.herd lazily; the coordinator owns the load cycle.
---@return table? herd
---@return string? err
local function herd_module()
    local ok, herd = pcall(require, 'ai.herd')
    if not ok or type(herd) ~= 'table' then
        return nil, 'ai.herd unavailable: ' .. tostring(herd)
    end
    return herd
end

---Notify with control characters stripped: error text comes from pcall
---over herd functions handling remote data, and raw ESC bytes would
---reach the terminal (terminal escape injection).
---@param message string
---@param level integer vim.log.levels
local function notify_clean(message, level)
    vim.notify(message:gsub('[%c]', ''), level)
end

---Normalize one raw herd.agents() entry; drop rows without a name.
---@param entry any Raw agent entry from herd.agents().
---@return HerdAgent? row
local function sanitize_agent(entry)
    if type(entry) ~= 'table' then
        return nil
    end
    if type(entry.name) ~= 'string' or entry.name == '' then
        return nil
    end
    -- Rendered fields are hostile: task is free-form on every insert
    -- path, and a single newline makes nvim_buf_set_lines throw,
    -- bricking the dashboard. Strip control characters (including ESC,
    -- which would otherwise reach the terminal via vim.notify) here at
    -- the choke point.
    local function clean(s)
        return s:gsub('[%c]', '')
    end
    local name = clean(entry.name)
    local status = 'unknown'
    if type(entry.status) == 'string' and STATUS_ORDER[entry.status] then
        status = entry.status
    end
    local cli = '?'
    if type(entry.cli) == 'string' and entry.cli ~= '' then
        cli = clean(entry.cli)
    end
    local machine = '?'
    if type(entry.machine) == 'string' and entry.machine ~= '' then
        machine = clean(entry.machine)
    end
    local task = ''
    if type(entry.task) == 'string' then
        task = clean(entry.task:sub(1, TASK_DISPLAY_MAX))
    end
    ---@type HerdAgent
    local row = {
        name = name,
        cli = cli,
        machine = machine,
        status = status,
        task = task,
    }
    return row
end

---@param a HerdAgent
---@param b HerdAgent
---@return boolean
local function agent_less(a, b)
    local order_a = STATUS_ORDER[a.status] or STATUS_ORDER.unknown
    local order_b = STATUS_ORDER[b.status] or STATUS_ORDER.unknown
    if order_a ~= order_b then
        return order_a < order_b
    end
    return a.name < b.name
end

---Format one dashboard row (or the header) from five fields.
---@param name string
---@param cli string
---@param machine string
---@param status string
---@param task string
---@return string
local function format_row(name, cli, machine, status, task)
    return string.format(ROW_FORMAT, name, cli, machine, status, task)
end

---Format one dashboard row from its agent entry.
---@param row HerdAgent
---@return string
local function row_text(row)
    local name = row.name
    local cli = row.cli
    local machine = row.machine
    local status = row.status
    local task = row.task
    return format_row(name, cli, machine, status, task)
end

---Read, sanitize, and sort agents; cap at ROWS_DISPLAY_MAX rows.
---@return HerdAgent[] agents
---@return string? err
local function read_agents()
    local herd, err = herd_module()
    if herd == nil then
        return {}, err
    end
    if type(herd.agents) ~= 'function' then
        return {}, 'ai.herd has no agents() function'
    end
    local ok, agents, agents_err = pcall(herd.agents)
    if not ok then
        return {}, 'herd.agents() failed: ' .. tostring(agents)
    end
    if type(agents) ~= 'table' then
        local detail = tostring(agents_err or agents)
        return {}, 'herd.agents() returned no table: ' .. detail
    end
    local out = {} ---@type HerdAgent[]
    for i = 1, math.min(#agents, ROWS_DISPLAY_MAX) do
        local row = sanitize_agent(agents[i])
        if row ~= nil then
            out[#out + 1] = row
        end
    end
    table.sort(out, agent_less)
    return out
end

---Draw the current rows into the dashboard buffer.
local function draw()
    assert(buf ~= nil, 'draw requires a buffer')
    assert(win ~= nil, 'draw requires a window')
    local header = format_row('name', 'cli', 'machine', 'status', 'task')
    local lines = {
        'herd agents (' .. #rows .. ')',
        '<CR> jump | p prompt | k kill | r refresh | q close',
        header,
    }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = row_text(row)
    end
    vim.bo[buf].modifiable = true
    -- Restore modifiable even when set_lines throws: otherwise the
    -- dashboard is left editable after a failed render.
    local set_ok, set_err = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    assert(set_ok, set_err)
end

---Agent row under the cursor, or nil when the cursor is on chrome.
---@return HerdAgent? row
local function row_under_cursor()
    if buf == nil or win == nil then
        return nil
    end
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end
    if not vim.api.nvim_win_is_valid(win) then
        return nil
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local index = cursor[1] - HEADER_LINE_COUNT
    if index < 1 or index > #rows then
        return nil
    end
    return rows[index]
end

---Prompt the agent under the cursor via vim.ui.input.
local function prompt_row()
    local row = row_under_cursor()
    if row == nil then
        return
    end
    local prompt = 'Prompt ' .. row.name .. ': '
    vim.ui.input({ prompt = prompt }, function(input)
        if input == nil or input == '' then
            return
        end
        local herd, err = herd_module()
        if herd == nil then
            vim.notify(err or 'ai.herd unavailable', vim.log.levels.ERROR)
            return
        end
        if type(herd.prompt_agent) ~= 'function' then
            vim.notify('ai.herd has no prompt_agent()', vim.log.levels.ERROR)
            return
        end
        local ok, prompt_err = pcall(herd.prompt_agent, row.name, input)
        if not ok then
            local detail = tostring(prompt_err)
            notify_clean('prompt failed: ' .. detail, vim.log.levels.ERROR)
            return
        end
        M.refresh()
    end)
end

---Kill the agent under the cursor after a Yes/No confirmation.
local function kill_row()
    local row = row_under_cursor()
    if row == nil then
        return
    end
    local choices = { 'Yes', 'No' }
    local select_opts = { prompt = 'Kill agent ' .. row.name .. '?' }
    vim.ui.select(choices, select_opts, function(choice)
        if choice ~= 'Yes' then
            return
        end
        local herd, err = herd_module()
        if herd == nil then
            vim.notify(err or 'ai.herd unavailable', vim.log.levels.ERROR)
            return
        end
        if type(herd.kill_agent) ~= 'function' then
            vim.notify('ai.herd has no kill_agent()', vim.log.levels.ERROR)
            return
        end
        local ok, kill_err = pcall(herd.kill_agent, row.name)
        if not ok then
            local detail = tostring(kill_err)
            notify_clean('kill failed: ' .. detail, vim.log.levels.ERROR)
            return
        end
        M.refresh()
    end)
end

---Wire the buffer-local dashboard keymaps onto a fresh buffer.
---@param target integer Buffer handle.
local function set_keymaps(target)
    local function map(lhs, rhs, desc_text)
        local opts = { buffer = target, silent = true, desc = desc_text }
        vim.keymap.set('n', lhs, rhs, opts)
    end
    map('<CR>', function()
        local row = row_under_cursor()
        if row ~= nil then
            M.jump(row.name)
        end
    end, 'Jump to agent pane')
    map('p', prompt_row, 'Prompt agent')
    map('k', kill_row, 'Kill agent')
    map('r', M.refresh, 'Refresh herd')
    map('q', M.close, 'Close herd')
end

---Open the herd dashboard, or focus it when it is already open.
function M.open()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        M.refresh()
        return
    end
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        for _, candidate in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(candidate) == buf then
                win = candidate
                vim.api.nvim_set_current_win(win)
                M.refresh()
                return
            end
        end
    end
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'herd://agents')
    vim.bo[buf].buftype = 'nofile'
    -- Wipe the buffer when its window closes: without this, M.close
    -- (or an external :close) leaks the named buffer and the next
    -- M.open hits E95 naming a fresh buffer 'herd://agents'.
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].filetype = 'herd-agents'
    set_keymaps(buf)
    local max_width = math.floor(vim.o.columns * WINDOW_WIDTH_RATIO)
    local width = math.min(WINDOW_WIDTH_MAX, max_width)
    local max_height = math.floor(vim.o.lines * WINDOW_HEIGHT_RATIO)
    local height = math.max(WINDOW_HEIGHT_MIN, max_height)
    win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Herd ',
    })
    M.refresh()
end

---Re-read agents and redraw. No-op when the window is not open.
function M.refresh()
    if win == nil or buf == nil then
        return
    end
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local agents, err = read_agents()
    rows = agents
    if err ~= nil then
        notify_clean(err, vim.log.levels.ERROR)
    end
    draw()
end

---Close the dashboard; safe to call when it is already closed.
function M.close()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
    buf = nil
end

---Jump to an agent's pane. Local agents switch the tmux client to the
---agent's session; remote agents are reported as not yet supported.
---@param name string Agent name to jump to.
---@return boolean ok False when the name is invalid or unknown.
---@return string? err Why the jump did not happen.
function M.jump(name)
    if type(name) ~= 'string' or name == '' then
        return false, 'agent name must be a non-empty string'
    end
    local agents = read_agents()
    local target = nil ---@type HerdAgent?
    for _, row in ipairs(agents) do
        if row.name == name then
            target = row
            break
        end
    end
    if target == nil then
        return false, 'unknown agent: ' .. name
    end
    if target.machine ~= 'local' then
        local message = 'remote attach is not implemented in v1'
        vim.notify(message, vim.log.levels.WARN)
        return true
    end
    if vim.env.TMUX == nil then
        local hint = 'outside tmux: attach with `tmux attach -t ' .. name .. '`'
        vim.notify(hint, vim.log.levels.WARN)
        return true
    end
    local argv = { 'tmux', 'switch-client', '-t', name }
    -- Synchronous: the user pressed a key, so a bounded wait is fine, and
    -- holding the handle keeps it alive until the switch completes.
    -- vim.system itself throws on spawn failure (e.g. tmux missing from
    -- PATH), so guard it like the wait below.
    local sys_ok, job = pcall(vim.system, argv, { text = true })
    if not sys_ok then
        notify_clean('tmux not available: ' .. tostring(job), vim.log.levels.WARN)
        return true
    end
    local _, completed = pcall(job.wait, job, TMUX_TIMEOUT_MS)
    if completed ~= nil and completed.code ~= 0 then
        vim.notify('tmux switch-client failed', vim.log.levels.WARN)
    end
    return true
end

return M
