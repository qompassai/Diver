--- lsp-health-probe.lua — hunt the `:checkhealth vim.lsp` "attempt to compare string with number" error.
---
--- WHAT IT DOES
---   1. Runs the real `require('vim.lsp.health').check()` exactly the way :checkhealth does,
---      but under xpcall+traceback, so a failure yields the FULL Lua stack trace
---      (:checkhealth swallows it and shows only the one-line message).
---   2. Runs 8 checks (4 validation / 4 adversarial) against the known string-vs-number
---      suspects inside vim.lsp.health: vim.spairs() over mixed-type keys, and the
---      log-level `<` comparison in check_log().
---
--- RUN IT (pick one; full config in both — never --clean/-u NONE/--noplugin):
---   A. Inside your live Neovim, where the error happens (best — clients already attached):
---        :luafile /path/to/lsp-health-probe.lua
---   B. Headless (probe opens a Lua file itself and waits for lua_ls to attach):
---        nvim --headless -c "luafile /path/to/lsp-health-probe.lua" -c "qa!"
---
--- OUTPUT: summary on stdout + two files next to this probe:
---   lsp-health-probe-results.txt  (check table)
---   lsp-health-probe-trace.txt    (full traceback, only if the error reproduces)
---
--- The probe mutates nothing: adversarial checks use synthetic locals only.

local PROBE_SRC = debug.getinfo(1, 'S').source:sub(2)
local PROBE_DIR = vim.fn.fnamemodify(PROBE_SRC, ':h')
local RESULTS_PATH = PROBE_DIR .. '/lsp-health-probe-results.txt'
local TRACE_PATH = PROBE_DIR .. '/lsp-health-probe-trace.txt'

local out_lines = {}
local function emit(fmt, ...)
    local line = string.format(fmt, ...)
    out_lines[#out_lines + 1] = line
    io.write(line .. '\n')
    io.flush()
end

local results = { pass = 0, fail = 0, skip = 0 }
local function check(id, kind, name, status, detail)
    results[status] = results[status] + 1
    emit('%-4s [%-4s] %s :: %s', id, kind, name, detail or '')
end

emit('== lsp-health-probe ==')
emit('nvim: %s', vim.fn.execute('version'):match('NVIM v[^\n]*') or '?')

-- ---------------------------------------------------------------------------
-- Phase 0: make sure an LSP client is attached (headless only; live nvim skips)
-- ---------------------------------------------------------------------------
if #vim.api.nvim_list_uis() == 0 and next(vim.lsp.get_clients()) == nil then
    vim.cmd('edit ' .. vim.fn.fnameescape(PROBE_SRC))
    emit('headless: waiting up to 15s for an LSP client to attach…')
    vim.wait(15000, function()
        return next(vim.lsp.get_clients()) ~= nil
    end, 100)
end
local clients = vim.lsp.get_clients()
emit('active clients: %d', #vim.tbl_keys(clients))

-- ---------------------------------------------------------------------------
-- Phase 1: run the REAL healthcheck under xpcall + traceback
-- ---------------------------------------------------------------------------
emit('--- phase 1: reproduce check() with full traceback ---')
local chunk = assert(loadstring("return require('vim.lsp.health').check()"))
local ok, err = xpcall(chunk, function(e)
    return debug.traceback(tostring(e), 2)
end)
if ok then
    emit('REPRODUCED: no — check() completed without error this run')
else
    emit('REPRODUCED: YES — full traceback written to %s', TRACE_PATH)
    local fh = assert(io.open(TRACE_PATH, 'w'))
    fh:write(err)
    fh:close()
    -- first frames on stdout so the culprit line is visible immediately
    local first = {}
    for line in (err .. '\n'):gmatch('([^\n]*)\n') do
        first[#first + 1] = line
        if #first >= 8 then
            break
        end
    end
    emit('traceback (first frames):\n%s', table.concat(first, '\n'))
end

-- ---------------------------------------------------------------------------
-- Phase 2: hypothesis checks (4 validation / 4 adversarial)
-- ---------------------------------------------------------------------------
emit('--- phase 2: hypothesis checks ---')

-- V1: check_log() does `current_log_level < log.levels.WARN`; a string level throws.
do
    local lvl = vim.lsp.log.get_level()
    check(
        'V1',
        'VAL',
        'log level is numeric (check_log comparison safe)',
        type(lvl) == 'number' and 'pass' or 'fail',
        string.format('get_level() -> %s (%s)', vim.inspect(lvl), type(lvl))
    )
end

-- V2: vim.spairs(vim.lsp._enabled_configs) sorts keys; mixed string/number keys throw.
do
    local bad = {}
    for name in pairs(vim.lsp._enabled_configs) do
        if type(name) ~= 'string' then
            bad[#bad + 1] = string.format('%s (%s)', vim.inspect(name), type(name))
        end
    end
    check(
        'V2',
        'VAL',
        '_enabled_configs keys all strings',
        #bad == 0 and 'pass' or 'fail',
        #bad == 0 and 'all string' or table.concat(bad, ', ')
    )
end

-- V3: vim.spairs(config) per enabled config; a config table with mixed-type keys throws.
do
    local offenders = {}
    for name in pairs(vim.lsp._enabled_configs) do
        local cfg = vim.lsp.config[name]
        if type(cfg) == 'table' then
            local types, n = {}, 0
            for k in pairs(cfg) do
                types[type(k)], n = true, n + 1
            end
            local distinct = vim.tbl_keys(types)
            if n > 1 and #distinct > 1 then
                offenders[#offenders + 1] = string.format('%s (key types: %s)', name, table.concat(distinct, ','))
            end
        end
    end
    table.sort(offenders)
    check(
        'V3',
        'VAL',
        'enabled configs have homogeneously-typed keys',
        #offenders == 0 and 'pass' or 'fail',
        #offenders == 0 and 'ok' or table.concat(offenders, '; ')
    )
end

-- V4: client ids / attached buffer keys numeric (format %d / decor_curbuf paths).
do
    if next(clients) == nil then
        check('V4', 'VAL', 'client ids and buffer keys numeric', 'skip', 'no active clients')
    else
        local bad = {}
        for _, c in pairs(clients) do
            if type(c.id) ~= 'number' then
                bad[#bad + 1] = string.format('%s.id=%s', c.name, vim.inspect(c.id))
            end
            for bufnr in pairs(c.attached_buffers or {}) do
                if type(bufnr) ~= 'number' then
                    bad[#bad + 1] = string.format('%s.buf=%s', c.name, vim.inspect(bufnr))
                end
            end
        end
        check(
            'V4',
            'VAL',
            'client ids and buffer keys numeric',
            #bad == 0 and 'pass' or 'fail',
            #bad == 0 and 'ok' or table.concat(bad, ', ')
        )
    end
end

-- A1: prove vim.spairs over mixed-type keys throws his error signature
-- (Lua reports "string with number" or "number with string" depending on sort order).
do
    local ok2, err2 = pcall(vim.spairs, { [1] = 'a', b = 'c' })
    local sig = type(err2) == 'string'
        and (
            err2:find('attempt to compare string with number', 1, true)
            or err2:find('attempt to compare number with string', 1, true)
        )
    check(
        'A1',
        'ADV',
        'mixed-key spairs produces the exact error signature',
        (not ok2 and sig) and 'pass' or 'fail',
        string.format(
            'threw=%s signature_match=%s err=%s',
            tostring(not ok2),
            tostring(sig ~= nil),
            vim.inspect(err2):sub(1, 90)
        )
    )
end

-- A2: prove `string < number` throws EXACTLY his error signature (no state mutated).
do
    local lvl_str = 'WARN'
    local ok2, err2 = pcall(function()
        return lvl_str < vim.lsp.log.levels.WARN
    end)
    local sig = type(err2) == 'string' and err2:find('attempt to compare string with number', 1, true)
    check(
        'A2',
        'ADV',
        'string < number produces the exact error signature',
        (not ok2 and sig) and 'pass' or 'fail',
        string.format(
            'threw=%s signature_match=%s err=%s',
            tostring(not ok2),
            tostring(sig ~= nil),
            vim.inspect(err2):sub(1, 90)
        )
    )
end

-- A3: hunt a different failure mode — enabled name with missing/non-table config.
do
    local bad = {}
    for name in pairs(vim.lsp._enabled_configs) do
        local cfg = vim.lsp.config[name]
        if type(cfg) ~= 'table' then
            bad[#bad + 1] = string.format('%s -> %s', name, type(cfg))
        end
    end
    check(
        'A3',
        'ADV',
        'every enabled name resolves to a config table',
        #bad == 0 and 'pass' or 'fail',
        #bad == 0 and 'ok' or table.concat(bad, ', ')
    )
end

-- A4: vim.spairs(vim.lsp._capability.all) sorts capability names; hunt numeric keys.
do
    local bad = {}
    for name in pairs(vim.lsp._capability.all) do
        if type(name) ~= 'string' then
            bad[#bad + 1] = string.format('%s (%s)', vim.inspect(name), type(name))
        end
    end
    check(
        'A4',
        'ADV',
        '_capability.all keys all strings',
        #bad == 0 and 'pass' or 'fail',
        #bad == 0 and 'ok' or table.concat(bad, ', ')
    )
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
emit('--- summary ---')
emit('pass=%d fail=%d skip=%d', results.pass, results.fail, results.skip)
emit('results file: %s', RESULTS_PATH)
local fh = assert(io.open(RESULTS_PATH, 'w'))
fh:write(table.concat(out_lines, '\n') .. '\n')
fh:close()

if not ok then
    os.exit(3) -- reproduced the healthcheck error; see trace file
elseif results.fail > 0 then
    os.exit(2) -- a hypothesis check failed
else
    os.exit(0)
end
