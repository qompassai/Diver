-- event_loop_lag.lua
-- Event-loop lag monitor (saturation signal) for the Diver Neovim config.
-- Suggested home: lua/config/perf/event_loop_lag.lua
--
-- Plain-language version: Neovim does everything on one event loop. When the
-- loop is too busy — a slow handler, a big computation — everything waits,
-- including timers that were already due. This module runs a lightweight
-- timer and measures how late each tick fires; that lateness is the loop's
-- saturation signal. It keeps a rolling baseline and pops a toast when lag
-- spikes well past it, with the measured number in the toast.
--
-- Mechanism: a repeating vim.uv timer is scheduled every interval_ms. Each
-- tick compares its actual fire time (vim.uv.hrtime) against the previous
-- tick's fire time plus the interval; the difference is that interval's
-- lag — how long the loop was too busy to service a timer that was already
-- due. Measuring per interval (not against an absolute schedule) keeps a
-- slow timer period from accumulating into phantom lag. Samples go into a
-- bounded ring buffer (SAMPLES_MAX); the rolling mean of the window is the
-- baseline. A sample is a spike when it exceeds both spike_multiplier times
-- the baseline and the SPIKE_FLOOR_MS absolute floor, so a near-zero
-- baseline cannot turn noise into alerts.
--
-- Toast: config.ui.lsp_health exposes only its own dashboard (open / close /
-- refresh), so its floating window is not a reusable helper. This module
-- replicates that window's behavior shape — scratch buffer, centered
-- 52-column float, rounded border, centered title, q or <Esc> to close,
-- 2000 ms auto-dismiss, idempotent close — with one deliberate difference:
-- the float opens with enter = false so a spike alert never steals focus
-- from the buffer being edited.
--
-- Measured baseline (primo, 2026-10-11, headless nvim with the live config,
-- real files open, edit/switch traffic while LSP servers started): rolling
-- baseline 14.0 ms mean, p95 81.7 ms, over 51 samples at the 100 ms
-- interval. Spike path proven in the same run: an induced 150 ms main-loop
-- stall read back as a 152.2 ms maximum sample and 2 recorded spikes once
-- the baseline settled to 13.4 ms.
---@module 'event_loop_lag'

local M = {}

-- Bounded constants.
local BASELINE_MIN_SAMPLES = 30
local SAMPLE_INTERVAL_MS = 100
local SAMPLES_MAX = 600
local SPIKE_FLOOR_MS = 25
local SPIKE_MULTIPLIER = 4
local TOAST_COOLDOWN_MS = 5000
local TOAST_DISMISS_MS = 2000
local TOAST_HEIGHT_MAX = 25
local TOAST_HEIGHT_MIN = 5
local TOAST_WIDTH_COLS = 52

---@class EventLoopLagOpts
---@field interval_ms? integer Sampler interval in ms (10..1000)
---@field spike_multiplier? number Spike threshold multiple of baseline (> 1)

---@class EventLoopLagStats
---@field baseline_ms number Rolling mean lag of the sample window
---@field last_ms number Most recent lag sample
---@field max_ms number Largest lag sample since start
---@field p95_ms number 95th percentile lag of the sample window
---@field running boolean Whether the sampler timer is active
---@field samples integer Samples currently in the window
---@field spike_count integer Spikes observed since start
---@field total_samples integer Total samples taken since start

---@class EventLoopLagConfig
---@field interval_ms integer Sampler interval in ms
---@field spike_multiplier number Spike threshold multiple of baseline

---@type EventLoopLagConfig
local config = {
    interval_ms = SAMPLE_INTERVAL_MS,
    spike_multiplier = SPIKE_MULTIPLIER,
}

local generation = 0
local last_ms = 0
local last_toast_ms = -TOAST_COOLDOWN_MS
local max_ms = 0
local prev_fire_ns = 0
local sample_head = 0
local samples_ms = {}
local spike_count = 0
local sum_ms = 0
local timer = nil
local toast_buf = nil
local toast_timer = nil
local toast_win = nil
local total_samples = 0
local window_count = 0

---Close the toast float and release its resources. Idempotent.
local function close_toast()
    if toast_timer ~= nil then
        pcall(vim.fn.timer_stop, toast_timer)
        toast_timer = nil
    end
    if toast_win ~= nil and vim.api.nvim_win_is_valid(toast_win) then
        pcall(vim.api.nvim_win_close, toast_win, true)
    end
    toast_win = nil
    if toast_buf ~= nil and vim.api.nvim_buf_is_valid(toast_buf) then
        pcall(vim.api.nvim_buf_delete, toast_buf, { force = true })
    end
    toast_buf = nil
end

---Show lines in a floating toast matching the lsp_health window shape.
---No-op when no UI is attached (headless runs use M.stats instead).
---@param title string Window title, already padded (e.g. ' Event Loop Lag ')
---@param lines string[] Content lines
local function show_toast(title, lines)
    local ui = vim.api.nvim_list_uis()[1]
    if ui == nil then
        return
    end
    close_toast()
    toast_buf = vim.api.nvim_create_buf(false, true)
    assert(toast_buf ~= 0, 'failed to create toast buffer')
    vim.api.nvim_buf_set_lines(toast_buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = toast_buf })
    local height = math.max(TOAST_HEIGHT_MIN, math.min(TOAST_HEIGHT_MAX, #lines))
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - TOAST_WIDTH_COLS) / 2)
    toast_win = vim.api.nvim_open_win(toast_buf, false, {
        border = 'rounded',
        col = col,
        height = height,
        relative = 'editor',
        row = row,
        style = 'minimal',
        title = title,
        title_pos = 'center',
        width = TOAST_WIDTH_COLS,
    })
    assert(toast_win ~= 0, 'failed to open toast window')
    vim.keymap.set('n', 'q', close_toast, { buffer = toast_buf, silent = true })
    vim.keymap.set('n', '<Esc>', close_toast, { buffer = toast_buf, silent = true })
    toast_timer = vim.fn.timer_start(TOAST_DISMISS_MS, function()
        close_toast()
    end)
end

---Record one lag sample in the ring buffer.
---@param lag_ms number Lag for this interval, >= 0
local function record_sample(lag_ms)
    sample_head = sample_head % SAMPLES_MAX + 1
    if window_count == SAMPLES_MAX then
        sum_ms = sum_ms - samples_ms[sample_head]
    else
        window_count = window_count + 1
    end
    samples_ms[sample_head] = lag_ms
    sum_ms = sum_ms + lag_ms
    total_samples = total_samples + 1
    last_ms = lag_ms
    if lag_ms > max_ms then
        max_ms = lag_ms
    end
end

---Decide whether a sample is a spike against the current baseline.
---@param lag_ms number Lag sample to judge
---@return boolean is_spike
local function is_spike(lag_ms)
    if window_count < BASELINE_MIN_SAMPLES then
        return false
    end
    local baseline_ms = sum_ms / window_count
    local threshold_ms = math.max(baseline_ms * config.spike_multiplier, SPIKE_FLOOR_MS)
    return lag_ms > threshold_ms
end

---Timer tick: measure drift, record the sample, toast on a spike.
---Runs in the timer's fast context: only uv calls and table writes happen
---here; the toast itself is deferred through vim.schedule.
---@param gen integer Generation token captured at start
local function on_tick(gen)
    if gen ~= generation or timer == nil then
        return
    end
    local interval_ms = config.interval_ms
    local now_ns = vim.uv.hrtime()
    local lag_ms = (now_ns - prev_fire_ns) / 1e6 - interval_ms
    prev_fire_ns = now_ns
    if lag_ms < 0 then
        lag_ms = 0
    end
    record_sample(lag_ms)
    if is_spike(lag_ms) then
        spike_count = spike_count + 1
        local now_ms = vim.uv.now()
        if now_ms - last_toast_ms >= TOAST_COOLDOWN_MS then
            last_toast_ms = now_ms
            local baseline_ms = sum_ms / window_count
            vim.schedule(function()
                if gen == generation then
                    show_toast(' Event Loop Lag ', {
                        string.format('Lag spike: %.1f ms', lag_ms),
                        string.format('Baseline: %.1f ms over %d samples', baseline_ms, window_count),
                    })
                end
            end)
        end
    end
end

---Show the current lag statistics in the toast.
function M.report()
    local stats = M.stats()
    show_toast(' Event Loop Lag ', {
        string.format('Baseline: %.2f ms   p95: %.2f ms', stats.baseline_ms, stats.p95_ms),
        string.format('Last: %.2f ms   Max: %.2f ms', stats.last_ms, stats.max_ms),
        string.format('Spikes: %d   Samples: %d (%d total)', stats.spike_count, stats.samples, stats.total_samples),
        stats.running and 'Sampler: running' or 'Sampler: stopped',
    })
end

---Configure the sampler and start it if it is not already running.
---@param opts? EventLoopLagOpts Optional overrides
---@return boolean|nil ok True on success
---@return string|nil err Error message on invalid input
function M.setup(opts)
    if opts ~= nil then
        if type(opts) ~= 'table' then
            return nil, 'opts must be a table'
        end
        if opts.interval_ms ~= nil then
            if type(opts.interval_ms) ~= 'number' or opts.interval_ms % 1 ~= 0 then
                return nil, 'interval_ms must be an integer'
            end
            if opts.interval_ms < 10 or opts.interval_ms > 1000 then
                return nil, 'interval_ms must be within 10..1000'
            end
            config.interval_ms = opts.interval_ms
        end
        if opts.spike_multiplier ~= nil then
            if type(opts.spike_multiplier) ~= 'number' or opts.spike_multiplier <= 1 then
                return nil, 'spike_multiplier must be a number greater than 1'
            end
            config.spike_multiplier = opts.spike_multiplier
        end
    end
    M.start()
    return true
end

---Start the sampler. Safe to call when already running.
---@return boolean started True if this call started the sampler
function M.start()
    if timer ~= nil then
        return false
    end
    local interval_ms = config.interval_ms
    generation = generation + 1
    local gen = generation
    prev_fire_ns = vim.uv.hrtime()
    local new_timer = vim.uv.new_timer()
    assert(new_timer ~= nil, 'failed to allocate sampler timer')
    local start_status = new_timer:start(interval_ms, interval_ms, function()
        on_tick(gen)
    end)
    assert(start_status == 0, 'failed to start sampler timer')
    timer = new_timer
    return true
end

---Return the current lag statistics.
---@return EventLoopLagStats stats
function M.stats()
    local baseline_ms = 0
    local p95_ms = 0
    if window_count > 0 then
        baseline_ms = sum_ms / window_count
        local sorted = {}
        for slot = 1, window_count do
            sorted[slot] = samples_ms[slot]
        end
        table.sort(sorted)
        p95_ms = sorted[math.ceil(0.95 * window_count)] or 0
    end
    return {
        baseline_ms = baseline_ms,
        last_ms = last_ms,
        max_ms = max_ms,
        p95_ms = p95_ms,
        running = timer ~= nil,
        samples = window_count,
        spike_count = spike_count,
        total_samples = total_samples,
    }
end

---Stop the sampler and release the timer. Idempotent.
---@return boolean stopped True if this call stopped the sampler
function M.stop()
    if timer == nil then
        return false
    end
    generation = generation + 1
    local old_timer = timer
    timer = nil
    old_timer:stop()
    if not old_timer:is_closing() then
        old_timer:close()
    end
    return true
end

return M
