-- /qompassai/Diver/lua/ai/debugbridge/commands.lua
-- Qompass AI Debug Bridge User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the debug bridge: security-scanned DAP
-- launches, session listing/killing, breakpoints, quarantine, and BSP
-- builds. Requiring this module registers the commands; it starts
-- nothing. All commands use the Dbg* namespace except BspBuild, which
-- had no prior definition; the BSP-targets command is DbgBspTargets
-- because lua/bsp/commands.lua already defines BspTargets.
--
-- Path rule (shared with ai.debugbridge.sessions): every user-supplied
-- path must be absolute and must not contain a '..' segment.
--
-- Launch pipeline (:DbgLaunch): validate target -> resolve the adapter
-- table from require('dap.dap').adapters -> scanbreak.gate({target},
-- {project_root}) -> sessions.acquire (this spawns the adapter; there
-- is no separate launch step) -> scanbreak.install_stop_hook with the
-- gate's flagged map. Fail-closed: a gate refusal (nil result, an
-- error, a 'malicious' verdict, or any unknown verdict) aborts before
-- anything is acquired, so nothing ever launches unscanned.

local M = {}

local LINE_NUMBER_MIN = 1
local PATH_DISPLAY_MAX = 80
-- Largest file set_breakpoint will load into a buffer: a 100 MB log
-- froze the editor for 4+ seconds on bufload. Breakpoints belong in
-- source files, not multi-gigabyte dumps.
local BREAKPOINT_FILE_BYTES_MAX = 1048576

---Verdicts that let a launch proceed; anything else refuses.
local GATE_PASS_VERDICTS = { clean = true, suspicious = true }

---Validate a user-supplied path the same way sessions.lua does:
---absolute, no '..' segment, no NUL byte, no control characters.
---@param path string
---@return boolean ok
---@return string? err
local function validate_path(path)
    if type(path) ~= 'string' or path == '' then
        return false, 'path must be a non-empty string'
    end
    if path:sub(1, 1) ~= '/' then
        return false, 'path must be absolute: ' .. path
    end
    -- Check '..' per segment (like sessions.validate_target): the old
    -- plain-search for the literal '%.%./' could never match, so a
    -- mid-path '..' sailed through.
    for segment in path:gmatch('[^/]+') do
        if segment == '..' then
            return false, 'path must not contain ..: ' .. path
        end
    end
    if path:find('%z') ~= nil then
        return false, 'path contains a NUL byte'
    end
    -- Control characters (newlines, ESC) in paths enable log injection:
    -- every notify echoes the raw path, so a crafted filename can fake
    -- 'quarantined:' / 'debugging' lines in :messages.
    if path:find('[%c]') ~= nil then
        return false, 'path contains control characters'
    end
    return true
end

---Require a debugbridge sibling module lazily with a clear error.
---@param name string Module name, e.g. 'ai.debugbridge.sessions'.
---@return table? module
---@return string? err
local function bridge_module(name)
    local ok, mod = pcall(require, name)
    if not ok or type(mod) ~= 'table' then
        return nil, name .. ' unavailable: ' .. tostring(mod)
    end
    return mod
end

---Log a quarantine event through ai.debugbridge.log when available.
---@param path string Quarantined path.
local function log_quarantine(path)
    local log, err = bridge_module('ai.debugbridge.log')
    if log == nil then
        vim.notify('quarantine logged nowhere: ' .. (err or '?'), vim.log.levels.WARN)
        return
    end
    if type(log.append) ~= 'function' then
        vim.notify('ai.debugbridge.log has no append()', vim.log.levels.WARN)
        return
    end
    local ok, appended = pcall(log.append, 'quarantine', { path = path })
    if not ok or not appended then
        vim.notify('log.append failed', vim.log.levels.WARN)
    end
end

---Quarantine an artifact path via ai.security for the scanbreak stop
---hook. Without this the hook kills a flagged session but reports
---"no artifact quarantined: ctx.quarantine_fn missing".
---@param path string
---@return string? dest, string? err
local function quarantine_artifact(path)
    local security, err = bridge_module('ai.security')
    if security == nil then
        return nil, err or 'ai.security unavailable'
    end
    if type(security.quarantine) ~= 'function' then
        return nil, 'ai.security has no quarantine()'
    end
    local ok, dest, qerr = pcall(security.quarantine, path)
    if not ok then
        return nil, 'quarantine raised: ' .. tostring(dest)
    end
    if dest == nil then
        return nil, qerr
    end
    return dest, nil
end

---Resolve an adapter name to its dap.ExecutableAdapter table.
---@param adapter_name string
---@return table? adapter
---@return string? err
local function resolve_adapter(adapter_name)
    local ok, dap = pcall(require, 'dap.dap')
    if not ok or type(dap) ~= 'table' then
        return nil, 'dap module unavailable'
    end
    if type(dap.adapters) ~= 'table' then
        return nil, 'dap.adapters registry unavailable'
    end
    local adapter = dap.adapters[adapter_name]
    if type(adapter) ~= 'table' then
        return nil, 'unknown adapter: ' .. adapter_name
    end
    return adapter
end

---Run the scanned launch pipeline. Fail-closed on any gate refusal.
---@param lang string Debug language.
---@param adapter_name string Adapter name from dap.adapters.
---@param target string Absolute debug target path.
local function launch_scanned(lang, adapter_name, target)
    if type(lang) ~= 'string' or lang == '' then
        vim.notify('DbgLaunch: lang must be a non-empty string', vim.log.levels.ERROR)
        return
    end
    if type(adapter_name) ~= 'string' or adapter_name == '' then
        vim.notify('DbgLaunch: adapter must be a non-empty string', vim.log.levels.ERROR)
        return
    end
    local valid, verr = validate_path(target)
    if not valid then
        vim.notify('DbgLaunch: ' .. tostring(verr), vim.log.levels.ERROR)
        return
    end
    local adapter, aerr = resolve_adapter(adapter_name)
    if adapter == nil then
        vim.notify('DbgLaunch: ' .. tostring(aerr), vim.log.levels.ERROR)
        return
    end
    local scanbreak, serr = bridge_module('ai.debugbridge.scanbreak')
    if scanbreak == nil then
        vim.notify('DbgLaunch: ' .. (serr or '?'), vim.log.levels.ERROR)
        return
    end
    if type(scanbreak.gate) ~= 'function' then
        vim.notify('DbgLaunch: scanbreak has no gate()', vim.log.levels.ERROR)
        return
    end
    -- The gate requires every file under project_root; the target's own
    -- directory is the tightest honest root.
    local root = vim.fn.fnamemodify(target, ':h')
    local gate_ok, result, gate_err = pcall(scanbreak.gate, { target }, { project_root = root })
    if not gate_ok then
        vim.notify('DbgLaunch: scanbreak.gate raised: ' .. tostring(result), vim.log.levels.ERROR)
        return
    end
    if result == nil then
        vim.notify('DbgLaunch refused by scanbreak.gate: ' .. tostring(gate_err), vim.log.levels.ERROR)
        return
    end
    local verdict = type(result) == 'table' and result.verdict or nil
    if not GATE_PASS_VERDICTS[verdict] then
        vim.notify('DbgLaunch refused: scanbreak verdict ' .. tostring(verdict), vim.log.levels.ERROR)
        return
    end
    local sessions, sessions_err = bridge_module('ai.debugbridge.sessions')
    if sessions == nil then
        vim.notify('DbgLaunch: ' .. (sessions_err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(sessions.acquire) ~= 'function' then
        vim.notify('DbgLaunch: sessions has no acquire()', vim.log.levels.ERROR)
        return
    end
    local config = {
        type = adapter_name,
        request = 'launch',
        name = 'debugbridge: ' .. target,
        program = target,
    }
    local acquire_opts = {
        lang = lang,
        adapter = adapter,
        config = config,
        target = target,
        project_root = root,
    }
    -- sessions.acquire spawns the adapter itself; there is no separate
    -- launch call. The stop hook installs on the live session below.
    local acquire_ok, key, _, acquire_err = pcall(sessions.acquire, acquire_opts)
    if not acquire_ok then
        vim.notify('DbgLaunch: acquire raised: ' .. tostring(key), vim.log.levels.ERROR)
        return
    end
    if key == nil then
        vim.notify('DbgLaunch acquire failed: ' .. tostring(acquire_err), vim.log.levels.ERROR)
        return
    end
    if type(scanbreak.install_stop_hook) == 'function' then
        -- Joined: stylua's 120-col repo config demands it single-line.
        local flagged = (type(result) == 'table' and type(result.flagged) == 'table') and result.flagged or {}
        local hook_ok, hooked, hook_err = pcall(
            scanbreak.install_stop_hook,
            key,
            flagged,
            { sessions_module = sessions, quarantine_fn = quarantine_artifact }
        )
        if not hook_ok then
            vim.notify('DbgLaunch: install_stop_hook raised: ' .. tostring(hooked), vim.log.levels.WARN)
        elseif not hooked then
            vim.notify('DbgLaunch: stop hook failed: ' .. tostring(hook_err), vim.log.levels.WARN)
        end
    end
    vim.notify('debugging ' .. target .. ' (' .. tostring(key) .. ')', vim.log.levels.INFO)
end

---Prompt for the missing DbgLaunch arguments, then launch scanned.
---@param lang string?
---@param adapter string?
---@param target string?
local function launch_interactive(lang, adapter, target)
    vim.ui.input({ prompt = 'Language: ', default = lang or '' }, function(got_lang)
        if got_lang == nil or got_lang == '' then
            return
        end
        vim.ui.input({ prompt = 'Adapter: ', default = adapter or '' }, function(got_adapter)
            if got_adapter == nil or got_adapter == '' then
                return
            end
            vim.ui.input({ prompt = 'Target (absolute path): ', default = target or '' }, function(got_target)
                if got_target == nil or got_target == '' then
                    return
                end
                launch_scanned(got_lang, got_adapter, got_target)
            end)
        end)
    end)
end

---Kill one session by key; refreshes the dashboard when open.
---@param key string
local function kill_session(key)
    local sessions, err = bridge_module('ai.debugbridge.sessions')
    if sessions == nil then
        vim.notify('DbgKill: ' .. (err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(sessions.kill) ~= 'function' then
        vim.notify('DbgKill: sessions has no kill()', vim.log.levels.ERROR)
        return
    end
    local ok, killed, kill_err = pcall(sessions.kill, key)
    if not ok then
        vim.notify('DbgKill raised: ' .. tostring(killed), vim.log.levels.ERROR)
        return
    end
    if not killed then
        vim.notify('DbgKill failed: ' .. tostring(kill_err), vim.log.levels.ERROR)
        return
    end
    vim.notify('killed session ' .. key, vim.log.levels.INFO)
    local ui_ok, ui = pcall(require, 'ai.debugbridge.ui')
    if ui_ok and type(ui) == 'table' and type(ui.refresh) == 'function' then
        ui.refresh()
    end
end

---Pick a session key interactively, then kill it.
local function kill_interactive()
    local sessions, err = bridge_module('ai.debugbridge.sessions')
    if sessions == nil then
        vim.notify('DbgKill: ' .. (err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(sessions.list) ~= 'function' then
        vim.notify('DbgKill: sessions has no list()', vim.log.levels.ERROR)
        return
    end
    local ok, listed = pcall(sessions.list)
    if not ok or type(listed) ~= 'table' or #listed == 0 then
        vim.notify('no debug sessions', vim.log.levels.WARN)
        return
    end
    local keys = {} ---@type string[]
    for _, entry in ipairs(listed) do
        if type(entry) == 'table' and type(entry.key) == 'string' then
            keys[#keys + 1] = entry.key
        end
    end
    if #keys == 0 then
        vim.notify('no debug sessions', vim.log.levels.WARN)
        return
    end
    vim.ui.select(keys, { prompt = 'Kill session:' }, function(choice)
        if choice ~= nil then
            kill_session(choice)
        end
    end)
end

---Set a DAP breakpoint directly (sessions-agnostic).
---@param file string Absolute file path.
---@param line integer 1-based line number.
local function set_breakpoint(file, line)
    local valid, verr = validate_path(file)
    if not valid then
        vim.notify('DbgBreak: ' .. tostring(verr), vim.log.levels.ERROR)
        return
    end
    if type(line) ~= 'number' or line < LINE_NUMBER_MIN then
        vim.notify('DbgBreak: line must be >= 1', vim.log.levels.ERROR)
        return
    end
    -- Bound the synchronous bufload: an unbounded read of a huge log,
    -- core dump, or disk image freezes the editor and blows up memory.
    local stat = vim.uv.fs_stat(file)
    if stat == nil or stat.type ~= 'file' then
        vim.notify('DbgBreak: not a regular file: ' .. file, vim.log.levels.ERROR)
        return
    end
    if stat.size > BREAKPOINT_FILE_BYTES_MAX then
        vim.notify('DbgBreak: file too large for a breakpoint: ' .. file, vim.log.levels.ERROR)
        return
    end
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    local breakpoints, err = bridge_module('dap.breakpoints')
    if breakpoints == nil then
        vim.notify('DbgBreak: ' .. (err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(breakpoints.set) ~= 'function' then
        vim.notify('DbgBreak: dap.breakpoints has no set()', vim.log.levels.ERROR)
        return
    end
    local ok, set_err = pcall(breakpoints.set, { replace = true }, bufnr, line)
    if not ok then
        vim.notify('DbgBreak failed: ' .. tostring(set_err), vim.log.levels.ERROR)
        return
    end
    vim.notify('breakpoint set: ' .. file .. ':' .. tostring(line), vim.log.levels.INFO)
end

---Quarantine a path through ai.security and log it.
---@param path string Absolute path to quarantine.
local function quarantine_path(path)
    local valid, verr = validate_path(path)
    if not valid then
        vim.notify('DbgQuarantine: ' .. tostring(verr), vim.log.levels.ERROR)
        return
    end
    local security, err = bridge_module('ai.security')
    if security == nil then
        vim.notify('DbgQuarantine: ' .. (err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(security.quarantine) ~= 'function' then
        vim.notify('DbgQuarantine: ai.security has no quarantine()', vim.log.levels.ERROR)
        return
    end
    local ok, dest = pcall(security.quarantine, path)
    if not ok then
        vim.notify('DbgQuarantine raised: ' .. tostring(dest), vim.log.levels.ERROR)
        return
    end
    if dest == nil then
        vim.notify('DbgQuarantine failed', vim.log.levels.ERROR)
        return
    end
    vim.notify('quarantined: ' .. tostring(dest), vim.log.levels.INFO)
    log_quarantine(tostring(dest))
end

---Compile all known targets under root; nil target_uris means "all".
---@param bsp table ai.debugbridge.bsp module.
---@param root string Absolute workspace root.
local function bsp_build(bsp, root)
    if type(bsp.build_targets) ~= 'function' then
        vim.notify('Bsp: bsp has no build_targets()', vim.log.levels.ERROR)
        return
    end
    bsp.build_targets(root, nil, function(build_err, result)
        if build_err ~= nil then
            vim.notify('BspBuild failed: ' .. tostring(build_err), vim.log.levels.ERROR)
            return
        end
        local status = type(result) == 'table' and result.status or '?'
        vim.notify('BspBuild ' .. tostring(status) .. ': ' .. root, vim.log.levels.INFO)
    end)
end

---Echo the target list for root, one per line.
---@param bsp table ai.debugbridge.bsp module.
---@param root string Absolute workspace root.
local function bsp_list_targets(bsp, root)
    if type(bsp.list_targets) ~= 'function' then
        vim.notify('Bsp: bsp has no list_targets()', vim.log.levels.ERROR)
        return
    end
    bsp.list_targets(root, function(list_err, targets)
        if list_err ~= nil then
            vim.notify('BspTargets failed: ' .. tostring(list_err), vim.log.levels.ERROR)
            return
        end
        if type(targets) ~= 'table' or #targets == 0 then
            vim.notify('no BSP targets under ' .. root, vim.log.levels.WARN)
            return
        end
        local chunks = {} ---@type table[]
        for _, target in ipairs(targets) do
            local name = '?'
            if type(target) == 'string' then
                name = target
            elseif type(target) == 'table' then
                if type(target.display_name) == 'string' and target.display_name ~= '' then
                    name = target.display_name
                elseif type(target.uri) == 'string' then
                    name = target.uri
                end
            end
            chunks[#chunks + 1] = { name:sub(1, PATH_DISPLAY_MAX), 'Normal' }
            chunks[#chunks + 1] = { '\n', 'Normal' }
        end
        vim.api.nvim_echo(chunks, false, {})
    end)
end

---Run one BSP verb through ai.debugbridge.bsp's callback API:
---ensure the session, then build or list targets.
---@param root string Absolute workspace root.
---@param verb string 'build' or 'targets'.
local function bsp_command(root, verb)
    local valid, verr = validate_path(root)
    if not valid then
        vim.notify('Bsp: ' .. tostring(verr), vim.log.levels.ERROR)
        return
    end
    local bsp, err = bridge_module('ai.debugbridge.bsp')
    if bsp == nil then
        vim.notify('Bsp: ' .. (err or '?'), vim.log.levels.ERROR)
        return
    end
    if type(bsp.ensure) ~= 'function' then
        vim.notify('Bsp: bsp has no ensure()', vim.log.levels.ERROR)
        return
    end
    bsp.ensure(root, function(ensure_err)
        if ensure_err ~= nil then
            vim.notify('Bsp ensure failed: ' .. tostring(ensure_err), vim.log.levels.ERROR)
            return
        end
        if verb == 'build' then
            bsp_build(bsp, root)
        else
            bsp_list_targets(bsp, root)
        end
    end)
end

---Register the debug bridge user commands. Called once from
---ai.debugbridge.setup(); the idempotent setup guard keeps this single.
function M.register()
    local api = vim.api

    api.nvim_create_user_command('DbgLaunch', function(command)
        local fargs = command.fargs
        if #fargs >= 3 then
            launch_scanned(fargs[1], fargs[2], fargs[3])
            return
        end
        launch_interactive(fargs[1], fargs[2], fargs[3])
    end, {
        nargs = '*',
        desc = 'Security-scanned debug launch: :DbgLaunch <lang> <adapter> <target>',
    })

    api.nvim_create_user_command('DbgSessions', function()
        local ui, err = bridge_module('ai.debugbridge.ui')
        if ui == nil then
            vim.notify('DbgSessions: ' .. (err or '?'), vim.log.levels.ERROR)
            return
        end
        if type(ui.open) ~= 'function' then
            vim.notify('DbgSessions: ui has no open()', vim.log.levels.ERROR)
            return
        end
        ui.open()
    end, { desc = 'Open the debug bridge dashboard' })

    api.nvim_create_user_command('DbgBreak', function(command)
        local fargs = command.fargs
        local file = fargs[1]
        if file == nil or file == '' then
            file = vim.api.nvim_buf_get_name(0)
        end
        local line = tonumber(fargs[2])
        if line == nil then
            line = vim.api.nvim_win_get_cursor(0)[1]
        end
        set_breakpoint(file, line)
    end, {
        nargs = '*',
        desc = 'Set a DAP breakpoint: :DbgBreak [file] [line]',
    })

    api.nvim_create_user_command('DbgKill', function(command)
        local key = command.args
        if key ~= '' then
            kill_session(key)
            return
        end
        kill_interactive()
    end, {
        nargs = '?',
        desc = 'Kill a debug session: :DbgKill [key]',
    })

    api.nvim_create_user_command('DbgQuarantine', function(command)
        quarantine_path(command.args)
    end, {
        nargs = 1,
        desc = 'Quarantine a suspicious file: :DbgQuarantine <absolute-path>',
    })

    api.nvim_create_user_command('BspBuild', function(command)
        local root = command.args
        if root == '' then
            root = vim.fn.getcwd()
        end
        bsp_command(root, 'build')
    end, {
        nargs = '?',
        desc = 'BSP build: :BspBuild [root]',
    })

    -- Named DbgBspTargets (not BspTargets): lua/bsp/commands.lua
    -- already defines BspTargets, and silently shadowing it would make
    -- :BspTargets load-order-dependent.
    api.nvim_create_user_command('DbgBspTargets', function(command)
        local root = command.args
        if root == '' then
            root = vim.fn.getcwd()
        end
        bsp_command(root, 'targets')
    end, {
        nargs = '?',
        desc = 'List BSP targets: :DbgBspTargets [root]',
    })

    return true
end

return M
