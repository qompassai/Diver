-- /qompassai/Diver/lua/ai/a2a/sdks.lua
-- Qompass AI A2A SDK Registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The official Agent2Agent SDKs, one per language: what they are,
-- whether they are installed here, and how to drive them from
-- inside Neovim. Diver's own A2A client (client.lua) stays the
-- default transport for v0.3 agents; the SDK drivers run the same
-- ops (card, send, stream, get, cancel) through each language's
-- native v1.0 client without leaving the editor.
--
-- Every SDK entry carries its install command, a detection probe,
-- and documentation links. Drivers live in sdk_drivers.lua: one
-- program per language using that SDK's documented client API.
-- User input (base URL, message, task id) reaches a driver as
-- process arguments (or a small args file for Maven), never
-- interpolated into generated code.
--
-- Wire note: the official SDKs are v1.0-era (ProtoJSON wire shapes);
-- Diver's own Lua client (client.lua) speaks the v0.3 JSON-RPC
-- binding. The two do not interop directly — use the SDK drivers
-- when the other side is a v1.0 agent.

local drivers = require('ai.a2a.sdk_drivers')

local M = {}

---@class A2aSdkDriver
---@field kind 'script'|'project'
---@field argv string[] script: runtime prefix; project: command run in the project dir.
---@field ext string script: temp file extension.
---@field args_via 'argv'|'env'|'file' How op args reach the driver.
---@field build fun(): string|table<string,string> script: program source;
---  project: relative-path -> file content for the whole scaffold.
---@field init_argv? string[] project: one-time setup command, run in the project dir.
---@field managed? string[] project: relative paths owned by the package
---  manager after init; never rewrite them once they exist.
---@field cwd? 'nvim' script: run from Neovim's cwd (for project-local installs).

---@class A2aSdkSpec
---@field lang string Registry key, e.g. 'python'.
---@field label string Display name, e.g. 'Python'.
---@field filetypes string[] Neovim filetypes wired to this SDK.
---@field package string Package name, e.g. 'a2a-sdk'.
---@field install_argv string[] Install command argv for display and terminal.
---@field detect_argv string[] Probe argv; exit 0 means installed.
---@field min_version string Minimum language version per the SDK docs.
---@field docs_url string SDK documentation.
---@field repo_url string SDK repository.
---@field verified boolean True once the driver is confirmed against the SDK docs.
---@field driver? A2aSdkDriver One driver program; handles every op via argv[1].

-- Registry order is the menu order.
---@type A2aSdkSpec[]
M.SDKS = {
    {
        lang = 'python',
        label = 'Python',
        filetypes = { 'python' },
        package = 'a2a-sdk',
        install_argv = { 'pip', 'install', 'a2a-sdk' },
        detect_argv = { 'python3', '-c', 'import a2a.client' },
        min_version = 'Python 3.10+',
        docs_url = 'https://a2a-protocol.org/latest/sdk/python/',
        repo_url = 'https://github.com/a2aproject/a2a-python',
        verified = true,
        driver = drivers.python,
    },
    {
        lang = 'typescript',
        label = 'TypeScript / JavaScript',
        filetypes = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
        package = '@a2a-js/sdk',
        install_argv = { 'npm', 'install', '@a2a-js/sdk' },
        detect_argv = { 'node', '--input-type=module', '-e', "import '@a2a-js/sdk'" },
        min_version = 'Node.js 20+',
        docs_url = 'https://a2a-protocol.org/latest/sdk/js/',
        repo_url = 'https://github.com/a2aproject/a2a-js',
        verified = true,
        driver = drivers.typescript,
    },
    {
        lang = 'go',
        label = 'Go',
        filetypes = { 'go' },
        package = 'github.com/a2aproject/a2a-go/v2',
        install_argv = { 'go', 'get', 'github.com/a2aproject/a2a-go/v2' },
        detect_argv = { 'go', 'version' },
        min_version = 'Go 1.26+',
        docs_url = 'https://a2a-protocol.org/latest/sdk/go/',
        repo_url = 'https://github.com/a2aproject/a2a-go',
        verified = true,
        driver = drivers.go,
    },
    {
        lang = 'java',
        label = 'Java',
        filetypes = { 'java' },
        package = 'org.a2aproject.sdk:a2a-java-sdk-client',
        install_argv = { 'mvn', 'dependency:get', '-Dartifact=org.a2aproject.sdk:a2a-java-sdk-client:1.3.2.Final' },
        detect_argv = { 'java', '-version' },
        min_version = 'Java 17+',
        docs_url = 'https://a2a-protocol.org/latest/sdk/java/',
        repo_url = 'https://github.com/a2aproject/a2a-java',
        verified = true,
        driver = drivers.java,
    },
    {
        lang = 'dotnet',
        label = '.NET (C#)',
        filetypes = { 'cs' },
        package = 'A2A',
        install_argv = { 'dotnet', 'add', 'package', 'A2A' },
        detect_argv = { 'dotnet', '--version' },
        min_version = '.NET 8+',
        docs_url = 'https://a2a-protocol.org/latest/sdk/dotnet/',
        repo_url = 'https://github.com/a2aproject/a2a-dotnet',
        verified = true,
        driver = drivers.dotnet,
    },
}

---@type table<string, A2aSdkSpec>
local by_lang = {}
for _, spec in ipairs(M.SDKS) do
    by_lang[spec.lang] = spec
end

---@param lang string
---@return A2aSdkSpec?
function M.get(lang)
    return by_lang[lang]
end

-- Detection ------------------------------------------------------
-- Runs every SDK probe concurrently; callback receives
-- { [lang] = { installed = boolean, detail = string } }.
-- Note: compiled-ecosystem probes (go/java/dotnet) only confirm
-- the toolchain, not the SDK package, which is project-scoped.
---@param callback fun(results: table<string, { installed: boolean, detail: string }>)
function M.detect_all(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local results = {}
    local pending = #M.SDKS
    if pending == 0 then
        vim.schedule(function()
            callback(results)
        end)
        return
    end
    for _, spec in ipairs(M.SDKS) do
        local argv = spec.detect_argv
        local ok, handle = pcall(vim.system, argv, { text = true }, function(res)
            local installed = res ~= nil and res.code == 0
            local detail = ''
            if res ~= nil then
                detail = (res.stderr ~= '' and res.stderr or res.stdout or ''):sub(1, 120)
            end
            results[spec.lang] = { installed = installed, detail = detail }
            pending = pending - 1
            if pending == 0 then
                vim.schedule(function()
                    callback(results)
                end)
            end
        end)
        if not ok or handle == nil then
            results[spec.lang] = { installed = false, detail = 'probe failed to spawn' }
            pending = pending - 1
            if pending == 0 then
                vim.schedule(function()
                    callback(results)
                end)
            end
        end
    end
end

-- Driver runner ----------------------------------------------------
local SCRIPT_MAX_BYTES = 65536
local OUTPUT_MAX_BYTES = 1024 * 1024
local DRIVER_TIMEOUT_MS = 120000

local last_base_url = ''

---@param dir string
---@param files table<string, string> relative path -> content
---@return boolean ok
local function write_files(dir, files)
    if vim.fn.mkdir(dir, 'p') == 0 then
        return false
    end
    for rel, content in pairs(files) do
        local path = dir .. '/' .. rel
        if vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p') == 0 then
            return false
        end
        local fh = io.open(path, 'w')
        if fh == nil then
            return false
        end
        fh:write(content)
        fh:close()
    end
    return true
end

---@param spec A2aSdkSpec
---@param driver A2aSdkDriver
---@param op string
---@param cli_args string[] { base_url, extra? }
---@param opts? { terminal?: boolean }
local function run_driver(spec, driver, op, cli_args, opts)
    opts = opts or {}
    local argv = {}
    local cwd = nil
    local env = nil
    local temp_path = nil
    if driver.kind == 'script' then
        local source = driver.build()
        assert(type(source) == 'string' and #source <= SCRIPT_MAX_BYTES, 'driver source out of bounds')
        temp_path = vim.fn.tempname() .. driver.ext
        if not write_files(vim.fn.fnamemodify(temp_path, ':h'), { [vim.fn.fnamemodify(temp_path, ':t')] = source }) then
            vim.notify('A2A SDK: cannot write temp script', vim.log.levels.ERROR)
            return
        end
        for _, a in ipairs(driver.argv) do
            argv[#argv + 1] = a
        end
        argv[#argv + 1] = temp_path
        if driver.cwd == 'nvim' then
            cwd = vim.fn.getcwd()
        end
    else
        local dir = vim.fn.stdpath('cache') .. '/a2a-sdk-drivers/' .. spec.lang
        local files = driver.build()
        assert(type(files) == 'table', 'project driver build must return path -> content')
        -- Files owned by the package manager after init (go.mod/go.sum)
        -- must survive: rewriting them would wipe the dependency state
        -- that init_argv created and break every later run.
        if driver.managed ~= nil then
            for _, rel in ipairs(driver.managed) do
                if vim.fn.filereadable(dir .. '/' .. rel) == 1 then
                    files[rel] = nil
                end
            end
        end
        if not write_files(dir, files) then
            vim.notify('A2A SDK: cannot write driver project', vim.log.levels.ERROR)
            return
        end
        cwd = dir
        for _, a in ipairs(driver.argv) do
            argv[#argv + 1] = a
        end
    end
    if driver.args_via == 'argv' then
        argv[#argv + 1] = op
        for _, a in ipairs(cli_args) do
            argv[#argv + 1] = a
        end
    elseif driver.args_via == 'env' then
        env = { A2A_OP = op, A2A_BASE = cli_args[1] or '', A2A_EXTRA = cli_args[2] or '' }
    elseif driver.args_via == 'file' then
        assert(cwd ~= nil, 'file arg passing needs a project dir')
        local fh = io.open(cwd .. '/args.txt', 'w')
        if fh == nil then
            vim.notify('A2A SDK: cannot write driver args', vim.log.levels.ERROR)
            if temp_path ~= nil then
                vim.fn.delete(temp_path)
            end
            return
        end
        fh:write(op .. '\n' .. (cli_args[1] or '') .. '\n' .. (cli_args[2] or '') .. '\n')
        fh:close()
    end
    local function cleanup()
        if temp_path ~= nil then
            vim.fn.delete(temp_path)
        end
    end
    local function spawn()
        if opts.terminal then
            vim.cmd('split')
            local job_opts = {}
            if cwd ~= nil then
                job_opts.cwd = cwd
            end
            if env ~= nil then
                job_opts.env = env
            end
            job_opts.on_exit = function()
                cleanup()
            end
            vim.fn.termopen(argv, job_opts)
            return
        end
        local sys_opts = { text = true, timeout = DRIVER_TIMEOUT_MS }
        if cwd ~= nil then
            sys_opts.cwd = cwd
        end
        if env ~= nil then
            sys_opts.env = env
        end
        local ok, handle = pcall(vim.system, argv, sys_opts, function(res)
            cleanup()
            local output = ''
            local ok = res ~= nil and res.code == 0
            if res ~= nil then
                output = (res.stdout or '') .. (res.stderr or '')
            end
            if #output > OUTPUT_MAX_BYTES then
                output = output:sub(1, OUTPUT_MAX_BYTES) .. '\n…[truncated]'
            end
            vim.schedule(function()
                if not ok then
                    vim.notify('A2A SDK (' .. spec.lang .. ') failed:\n' .. output, vim.log.levels.ERROR)
                else
                    vim.notify(output ~= '' and output or '(no output)', vim.log.levels.INFO)
                end
            end)
        end)
        if not ok or handle == nil then
            cleanup()
            vim.schedule(function()
                vim.notify(
                    'A2A SDK (' .. spec.lang .. ') failed to start; is the toolchain installed?',
                    vim.log.levels.ERROR
                )
            end)
        end
    end
    if driver.kind == 'project' and driver.init_argv ~= nil then
        local marker = cwd .. '/.diver-ready'
        if vim.fn.filereadable(marker) == 0 then
            vim.notify('A2A SDK (' .. spec.label .. '): first run, setting up driver project…', vim.log.levels.INFO)
            local init_ok, init_handle = pcall(
                vim.system,
                driver.init_argv,
                { text = true, timeout = DRIVER_TIMEOUT_MS, cwd = cwd },
                function(res)
                    vim.schedule(function()
                        if res == nil or res.code ~= 0 then
                            local out = res and ((res.stdout or '') .. (res.stderr or '')) or ''
                            vim.notify('A2A SDK setup failed:\n' .. out, vim.log.levels.ERROR)
                            return
                        end
                        local fh = io.open(marker, 'w')
                        if fh ~= nil then
                            fh:close()
                        end
                        spawn()
                    end)
                end
            )
            if not init_ok or init_handle == nil then
                vim.schedule(function()
                    vim.notify('A2A SDK setup failed to start; is the toolchain installed?', vim.log.levels.ERROR)
                end)
            end
            return
        end
    end
    spawn()
end

-- Ops ---------------------------------------------------------------
-- Each op asks for the agent's base URL (the SDKs resolve the card
-- themselves), then hands off to the language's driver program.
-- Unverified SDKs stop here with a docs pointer.
---@param spec A2aSdkSpec
---@param op string
---@return A2aSdkDriver?
local function need_driver(spec, op)
    if not spec.verified or spec.driver == nil then
        vim.notify(
            string.format('A2A SDK (%s): %s driver not verified yet — see %s', spec.label, op, spec.docs_url),
            vim.log.levels.WARN
        )
        return nil
    end
    return spec.driver
end

---@param callback fun(base_url: string?)
local function ask_base_url(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    vim.ui.input({ prompt = 'Agent base URL: ', default = last_base_url }, function(input)
        if input == nil or input == '' then
            callback(nil)
            return
        end
        last_base_url = input
        callback(input)
    end)
end

---@param lang string
---@param op 'card'|'send'|'stream'|'get'|'cancel'
function M.op(lang, op)
    local spec = by_lang[lang]
    if spec == nil then
        vim.notify('A2A SDK: unknown language ' .. tostring(lang), vim.log.levels.ERROR)
        return
    end
    local driver = need_driver(spec, op)
    if driver == nil then
        return
    end
    if op == 'card' then
        ask_base_url(function(base)
            if base == nil then
                return
            end
            run_driver(spec, driver, op, { base })
        end)
        return
    end
    if op == 'get' or op == 'cancel' then
        ask_base_url(function(base)
            if base == nil then
                return
            end
            vim.ui.input({ prompt = 'Task ID: ' }, function(task_id)
                if task_id == nil or task_id == '' then
                    return
                end
                run_driver(spec, driver, op, { base, task_id })
            end)
        end)
        return
    end
    -- send / stream
    ask_base_url(function(base)
        if base == nil then
            return
        end
        vim.ui.input({ prompt = 'Message: ' }, function(message)
            if message == nil or message == '' then
                return
            end
            run_driver(spec, driver, op, { base, message }, { terminal = op == 'stream' })
        end)
    end)
end

-- Buffer wiring -------------------------------------------------------
-- One FileType autocmd covers every SDK language: opening a file of
-- that type wires the buffer-local <LocalLeader>aa* maps. Kept here
-- (instead of one line per lua/config/lang file) so the SDK keymap
-- set has a single owner.
local wire_group = nil

---@param lang string
function M.wire(lang)
    local spec = by_lang[lang]
    if spec == nil then
        return
    end
    for _, ft in ipairs(spec.filetypes) do
        vim.api.nvim_create_autocmd('FileType', {
            group = wire_group,
            pattern = ft,
            callback = function()
                M.wire_buffer(lang)
            end,
            desc = 'Wire A2A ' .. spec.label .. ' SDK maps',
        })
    end
end

function M.setup()
    if wire_group ~= nil then
        return
    end
    wire_group = vim.api.nvim_create_augroup('A2aSdkWire', { clear = true })
    for _, spec in ipairs(M.SDKS) do
        M.wire(spec.lang)
    end
end

-- Sets buffer-local <LocalLeader>aa* maps; each op degrades gracefully
-- when the SDK is missing or unverified.
---@param lang string
function M.wire_buffer(lang)
    local spec = by_lang[lang]
    if spec == nil then
        return
    end
    local maps = {
        { 'aaa', 'card', 'Fetch agent card via ' .. spec.label .. ' SDK' },
        { 'aas', 'send', 'Send A2A message via ' .. spec.label .. ' SDK' },
        { 'aaS', 'stream', 'Stream A2A message via ' .. spec.label .. ' SDK' },
        { 'aag', 'get', 'Get A2A task via ' .. spec.label .. ' SDK' },
        { 'aac', 'cancel', 'Cancel A2A task via ' .. spec.label .. ' SDK' },
        { 'aai', 'menu', 'A2A SDK install menu' },
    }
    for _, m in ipairs(maps) do
        local key, op, desc = m[1], m[2], m[3]
        vim.keymap.set('n', '<LocalLeader>' .. key, function()
            if op == 'menu' then
                M.install_menu()
            else
                M.op(lang, op)
            end
        end, { buffer = true, silent = true, desc = desc })
    end
end

-- Install ---------------------------------------------------------------
---@param spec A2aSdkSpec
function M.install(spec)
    assert(spec ~= nil, 'spec required')
    local cmd = table.concat(vim.tbl_map(vim.fn.shellescape, spec.install_argv), ' ')
    vim.cmd('split | terminal ' .. cmd)
    vim.notify('Installing ' .. spec.package .. ' — watch the terminal below', vim.log.levels.INFO)
end

-- Floating install menu ---------------------------------------------------
-- One float, keyboard navigated: j/k move, <CR> installs, q closes.
-- Statuses come from detect_all; compiled-ecosystem entries are
-- labeled toolchain-only so nobody mistakes them for SDK-present.
local menu_buf = nil

local function menu_lines(results)
    local lines = { ' A2A SDKs — <CR> install, q close ', '' }
    for i, spec in ipairs(M.SDKS) do
        local r = results[spec.lang]
        local mark = (r and r.installed) and '✓' or '✗'
        local note = ''
        if spec.lang == 'go' or spec.lang == 'java' or spec.lang == 'dotnet' then
            note = (r and r.installed) and ' (toolchain)' or ' (toolchain missing?)'
        elseif not spec.verified then
            note = ' (drivers pending docs)'
        end
        lines[#lines + 1] = string.format('%d. [%s] %-22s %-18s%s', i, mark, spec.label, spec.package, note)
    end
    return lines
end

function M.install_menu()
    M.detect_all(function(results)
        if menu_buf ~= nil and vim.api.nvim_buf_is_valid(menu_buf) then
            vim.api.nvim_buf_delete(menu_buf, { force = true })
        end
        menu_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(menu_buf, 'a2a://sdks')
        vim.bo[menu_buf].filetype = 'a2a-sdks'
        vim.bo[menu_buf].modifiable = false
        local width = 64
        local height = #M.SDKS + 4
        vim.api.nvim_open_win(menu_buf, true, {
            relative = 'editor',
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = 'minimal',
            border = 'rounded',
            title = ' A2A SDKs ',
        })
        local cursor = 3 -- first entry line (1-based in buffer)
        local function render()
            vim.bo[menu_buf].modifiable = true
            vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, menu_lines(results))
            vim.bo[menu_buf].modifiable = false
            vim.api.nvim_win_set_cursor(0, { cursor, 0 })
        end
        local function close()
            if vim.api.nvim_win_is_valid(0) then
                vim.cmd('close')
            end
        end
        local function move(delta)
            cursor = math.min(math.max(cursor + delta, 3), 3 + #M.SDKS - 1)
            render()
        end
        local function choose()
            local spec = M.SDKS[cursor - 2]
            if spec ~= nil then
                close()
                M.install(spec)
            end
        end
        local opts = { buffer = menu_buf, silent = true, nowait = true }
        vim.keymap.set('n', 'q', close, opts)
        vim.keymap.set('n', '<Esc>', close, opts)
        vim.keymap.set('n', 'j', function()
            move(1)
        end, opts)
        vim.keymap.set('n', 'k', function()
            move(-1)
        end, opts)
        vim.keymap.set('n', '<CR>', choose, opts)
        vim.keymap.set('n', '<Down>', function()
            move(1)
        end, opts)
        vim.keymap.set('n', '<Up>', function()
            move(-1)
        end, opts)
        render()
    end)
end

return M
