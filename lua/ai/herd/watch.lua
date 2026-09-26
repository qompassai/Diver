-- /qompassai/Diver/lua/ai/herd/watch.lua
-- Herdr agent pane watcher (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Pane-state classifier plus a timer-driven poller that watches tmux
-- panes running agent CLIs and reports each tracked agent as 'working',
-- 'blocked', 'idle', or 'dead'. All tmux access goes through the
-- lazily-required ai.herd.tmux module (required inside the tick, never
-- at the top level, to avoid load cycles); this module shells nothing.
-- classify() is pure (no vim.* calls, no I/O) and unit-testable.

local M = {}

---@alias HerdStatus 'working'|'blocked'|'idle'|'dead'

local TRACKED_MAX = 64
local CAPTURE_LINE_COUNT = 120
local INTERVAL_MS_DEFAULT = 5000
local INTERVAL_MS_MIN = 1000
local INTERVAL_MS_MAX = 60000
local STALL_TICKS = 2
local TAIL_LINE_COUNT = 30
local HASH_HEAD_CHARS = 64
local HASH_TAIL_CHARS = 64

---@class HerdCliPatterns
---@field blocked string[] Lua patterns marking an input/approval prompt.
---@field idle_prompt string[] Lua patterns marking a bare input prompt line.

---@type table<string, HerdCliPatterns>
local CLI_PATTERNS = {
    -- claude: 'Do you want to proceed?' permission dialogs and the
    -- '❯ 1. / ❯ 2.' option pickers; bare '❯' prompt when idle.
    claude = {
        blocked = {
            'Do you want to proceed%?',
            'Allow this action%?',
            '❯ 1%.',
            '❯ 2%.',
        },
        idle_prompt = { '^❯%s*$' },
    },
    -- codex: '(y/n)' and 'Please confirm' approval prompts; '›' prompt
    -- when idle.
    codex = {
        blocked = {
            'Please confirm',
            '%(y/n%)',
            'esc to approve',
        },
        idle_prompt = { '^›%s*$' },
    },
    -- opencode: 'Proceed?' / 'needs your approval' prompts; '❯' prompt
    -- when idle.
    opencode = {
        blocked = {
            'Proceed%?',
            'needs your approval',
        },
        idle_prompt = { '^❯%s*$' },
    },
}

-- Fallback blocked patterns for unknown clis: the generic question and
-- approval phrasings every agent CLI converges on.
local GENERIC_BLOCKED = {
    'Do you want to proceed%?',
    'Proceed%?',
    '%(y/n%)',
    '❯ 1%.',
    '❯ 2%.',
    'needs your approval',
    'Allow this action%?',
    'Please confirm',
    'esc to approve',
}

local GENERIC_IDLE_PROMPT = { '^❯%s*$', '^›%s*$' }

-- Markers that mean the pane's session is gone, not just quiet.
local DEAD_MARKERS = {
    'session not found',
    'failed to connect to server',
    'no server running',
    "can't find session",
}

-- Activity markers that prove the agent is doing work right now:
-- spinner glyphs, live-progress hints, and running/thinking banners.
local ACTIVITY_MARKERS = {
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
    'esc to interrupt',
    'Baking…',
    'Thinking…',
    'Working…',
    'Running…',
}

---@class HerdWatchedAgent
---@field cli string CLI name, used to pick the pattern table.
---@field target string tmux target passed to capture_pane.
---@field task string? Optional human-readable task label.
---@field status HerdStatus? Last reported status; nil before first poll.
---@field hash string? Output hash from the last successful capture.
---@field unchanged_ticks integer Consecutive 'working' ticks with no
---output change.
---@field updated_at integer? vim.uv.now() of the last poll.

local agents = {} ---@type table<string, HerdWatchedAgent>
local timer = nil ---@type uv.uv_timer_t?

---Return the blocked patterns for a CLI, falling back to GENERIC_BLOCKED.
---@param cli string
---@return string[]
local function blocked_patterns(cli)
    local entry = CLI_PATTERNS[cli:lower()]
    if entry ~= nil then
        return entry.blocked
    end
    return GENERIC_BLOCKED
end

---Return the idle-prompt line patterns for a CLI.
---@param cli string
---@return string[]
local function idle_prompts(cli)
    local entry = CLI_PATTERNS[cli:lower()]
    if entry ~= nil then
        return entry.idle_prompt
    end
    return GENERIC_IDLE_PROMPT
end

---Last non-blank line of the text, or '' when there is none.
---@param text string
---@return string
local function last_non_blank_line(text)
    local last = ''
    for line in text:gmatch('[^\n]*') do
        if line:find('%S') ~= nil then
            last = line
        end
    end
    return last
end

---Last line_count lines of the text as one string.
---@param text string
---@param line_count integer
---@return string
local function last_lines(text, line_count)
    local lines = {}
    for line in text:gmatch('[^\n]*') do
        lines[#lines + 1] = line
    end
    local from = #lines - line_count + 1
    if from < 1 then
        from = 1
    end
    return table.concat(lines, '\n', from)
end

---True when any plain marker appears in the (case-folded) text.
---@param text string
---@param markers string[]
---@return boolean
local function contains_any(text, markers)
    local folded = text:lower()
    for _, marker in ipairs(markers) do
        if folded:find(marker:lower(), 1, true) ~= nil then
            return true
        end
    end
    return false
end

---Classify a captured pane's text into an agent status. Pure function:
---no vim.* calls, no I/O.
---@param text string Captured pane output.
---@param cli string CLI name, selects the pattern table.
---@return HerdStatus
function M.classify(text, cli)
    assert(type(text) == 'string', 'text must be a string')
    assert(type(cli) == 'string', 'cli must be a string')
    if text:find('%S') == nil then
        return 'dead'
    end
    if contains_any(text, DEAD_MARKERS) then
        return 'dead'
    end
    for _, pattern in ipairs(blocked_patterns(cli)) do
        if text:find(pattern) ~= nil then
            return 'blocked'
        end
    end
    local last = last_non_blank_line(text)
    for _, pattern in ipairs(idle_prompts(cli)) do
        if last:find(pattern) ~= nil then
            local tail = last_lines(text, TAIL_LINE_COUNT)
            if not contains_any(tail, ACTIVITY_MARKERS) then
                return 'idle'
            end
        end
    end
    return 'working'
end

---Output hash used for stall detection: cheap and deliberately lossy --
---length plus the first/last HASH_*_CHARS characters. Two captures with
---the same hash are treated as "no visible progress" even though
---interior lines could theoretically differ without moving the ends.
---@param text string
---@return string
local function output_hash(text)
    local head = text:sub(1, HASH_HEAD_CHARS)
    local tail = text:sub(-HASH_TAIL_CHARS)
    return #text .. ':' .. head .. ':' .. tail
end

---Sorted tracked names so each tick polls in a deterministic order.
---@return string[]
local function sorted_names()
    local names = {}
    for name in pairs(agents) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---@return integer
local function tracked_count()
    local count = 0
    for _ in pairs(agents) do
        count = count + 1
    end
    return count
end

---@param value any
---@return boolean
local function is_nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---Capture a pane's text; nil when the tmux module is missing, the call
---fails, or the result is not a string. A nil result means 'dead'.
---@param tmux table ai.herd.tmux module handle.
---@param target string tmux target to capture.
---@return string? text
local function capture_text(tmux, target)
    local ok, captured = pcall(tmux.capture_pane, target, CAPTURE_LINE_COUNT)
    if ok and type(captured) == 'string' then
        return captured
    end
    return nil
end

---Poll one tracked agent: capture its pane, classify, apply the stall
---rule, notify exactly once per blocked transition, record state.
---@param name string
---@param agent HerdWatchedAgent
local function poll_agent(name, agent)
    local ok_require, tmux = pcall(require, 'ai.herd.tmux')
    local text = nil ---@type string?
    if ok_require and type(tmux) == 'table' then
        text = capture_text(tmux, agent.target)
    end
    local status ---@type HerdStatus
    if text == nil then
        status = 'dead'
    else
        local hash = output_hash(text)
        status = M.classify(text, agent.cli)
        if status == 'working' then
            if agent.hash ~= nil and agent.hash == hash then
                agent.unchanged_ticks = agent.unchanged_ticks + 1
            else
                agent.unchanged_ticks = 0
            end
            -- Stall rule: 'working' with no visible output change for
            -- STALL_TICKS consecutive ticks is reported as 'idle'.
            if agent.unchanged_ticks >= STALL_TICKS then
                status = 'idle'
            end
        else
            agent.unchanged_ticks = 0
        end
        agent.hash = hash
    end
    local previous = agent.status
    if status == 'blocked' and previous ~= 'blocked' then
        local msg = 'herd: agent "' .. name .. '" needs input'
        vim.notify(msg, vim.log.levels.WARN)
    end
    agent.status = status
    agent.updated_at = vim.uv.now()
end

---One timer tick: poll every tracked agent in sorted-name order.
local function tick()
    for _, name in ipairs(sorted_names()) do
        local agent = agents[name]
        if agent ~= nil then
            poll_agent(name, agent)
        end
    end
end

---Register an agent for polling. Re-tracking a name replaces its entry.
---@param name string Non-empty agent name (watch key).
---@param target string Non-empty tmux target for capture_pane.
---@param cli string Non-empty CLI name, selects the pattern table.
---@param task string? Optional human-readable task label.
---@return boolean ok
---@return string? err
function M.track(name, target, cli, task)
    assert(is_nonempty_string(name), 'name must be a non-empty string')
    assert(is_nonempty_string(target), 'target must be a non-empty string')
    assert(is_nonempty_string(cli), 'cli must be a non-empty string')
    if task ~= nil then
        assert(type(task) == 'string', 'task must be a string')
    end
    if agents[name] == nil and tracked_count() >= TRACKED_MAX then
        return nil, 'watch list is full (' .. TRACKED_MAX .. ' agents)'
    end
    agents[name] = {
        cli = cli,
        target = target,
        task = task,
        status = 'unknown',
        hash = nil,
        unchanged_ticks = 0,
        updated_at = nil,
    }
    return true, nil
end

---Remove a tracked agent. No error when the name is not tracked.
---@param name string
function M.untrack(name)
    assert(type(name) == 'string', 'name must be a string')
    agents[name] = nil
end

---Start the poll timer. interval_ms defaults to 5000 and is clamped to
---[1000, 60000].
---@param interval_ms integer?
---@return boolean ok
---@return string? err
function M.start(interval_ms)
    if interval_ms == nil then
        interval_ms = INTERVAL_MS_DEFAULT
    end
    if type(interval_ms) ~= 'number' or interval_ms ~= interval_ms then
        return nil, 'interval_ms must be a number'
    end
    interval_ms = math.floor(interval_ms)
    if interval_ms < INTERVAL_MS_MIN then
        interval_ms = INTERVAL_MS_MIN
    end
    if interval_ms > INTERVAL_MS_MAX then
        interval_ms = INTERVAL_MS_MAX
    end
    if timer ~= nil then
        return nil, 'already running'
    end
    local handle = vim.uv.new_timer()
    if handle == nil then
        return nil, 'could not create timer'
    end
    timer = handle
    handle:start(interval_ms, interval_ms, vim.schedule_wrap(tick))
    return true, nil
end

---Stop the poll timer. Idempotent.
function M.stop()
    if timer == nil then
        return
    end
    local handle = timer
    timer = nil
    handle:stop()
    handle:close()
end

---@class HerdAgentSnapshot
---@field status HerdStatus?
---@field cli string
---@field target string
---@field task string?
---@field updated_at integer?

---Copy of the tracked state: name -> HerdAgentSnapshot.
---@return table<string, HerdAgentSnapshot>
function M.state()
    local snapshot = {}
    for name, agent in pairs(agents) do
        snapshot[name] = {
            status = agent.status,
            cli = agent.cli,
            target = agent.target,
            task = agent.task,
            updated_at = agent.updated_at,
        }
    end
    return snapshot
end

return M
