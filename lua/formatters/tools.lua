-- #################################################################
-- ~/.config/nvim/lua/formatters/tools.lua
-- Native formatter status, release checks and installation menus
-- #################################################################
---@source https://github.com/qompassai/diver
local api = vim.api
local uv = vim.uv
local catalog = require('formatters.catalog')
local process = require('formatters.process')

local M = {
    results = {},
    options = {
        auto_prompt = true,
        check_latest = true,
        latest_ttl = 24 * 60 * 60,
    },
}

local latest_cache = {}
local prompted = {}
local installing = false
local prompt_open = false

local function clean(value)
    return tostring(value):gsub('[%z\1-\31\127]', ' '):sub(1, 2048)
end

local function version(value)
    if type(value) ~= 'string' then
        return nil
    end
    return value:match('(%d+%.%d+%.%d+)') or value:match('(%d+%.%d+)')
end

local function compare(a, b)
    local left, right = {}, {}
    for number in a:gmatch('%d+') do
        left[#left + 1] = tonumber(number)
    end
    for number in b:gmatch('%d+') do
        right[#right + 1] = tonumber(number)
    end
    for index = 1, math.max(#left, #right) do
        local x, y = left[index] or 0, right[index] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

local function decode(text)
    local ok, value = pcall(vim.json.decode, text)
    return ok and value or nil
end

local function read_json(path)
    local stat = uv.fs_stat(path)
    if not stat or stat.type ~= 'file' or stat.size > 65536 then
        return nil
    end
    local fd = uv.fs_open(path, 'r', 0)
    if not fd then
        return nil
    end
    local text = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    return text and decode(text) or nil
end

local function executable(definition)
    local command = definition.cmd
    ---@type string[]
    local candidates = {}

    if type(command) == 'string' then
        candidates[1] = command
    elseif type(command) == 'table' then
        ---@cast command string[]
        for _, candidate in ipairs(command) do
            if type(candidate) == 'string' then
                candidates[#candidates + 1] = candidate
            end
        end
    end

    for _, candidate in ipairs(candidates) do
        if vim.fn.executable(candidate) == 1 then
            return vim.fn.exepath(candidate)
        end
    end
end

local function finish(name, item, callback)
    M.results[name] = item
    callback(vim.deepcopy(item))
end

local function fetch_latest(name, entry, callback)
    local cached = latest_cache[name]
    if cached and os.time() - cached.time < M.options.latest_ttl then
        callback(cached.version, cached.error)
        return
    end

    if not entry.source or vim.fn.executable('curl') ~= 1 then
        callback(nil, 'No release source or curl executable')
        return
    end

    process.run({
        'curl',
        '--disable',
        '--fail',
        '--silent',
        '--show-error',
        '--location',
        '--proto',
        '=https',
        '--proto-redir',
        '=https',
        '--connect-timeout',
        '3',
        '--max-time',
        '8',
        '--user-agent',
        'Diver-native-formatters',
        entry.source.url,
    }, { cwd = catalog.root }, function(result)
        local value = result.ok and decode(result.text) or nil

        local source_field = entry.source.field
        ---@type string[]
        local fields = {}

        if type(source_field) == 'string' then
            ---@cast source_field string
            for field in string.gmatch(source_field, '[^.]+') do
                fields[#fields + 1] = field
            end
        elseif type(source_field) == 'table' then
            ---@cast source_field string[]
            for _, field in ipairs(source_field) do
                if type(field) == 'string' then
                    fields[#fields + 1] = field
                end
            end
        end

        for _, field in ipairs(fields) do
            value = type(value) == 'table' and value[field] or nil
        end

        local parsed
        if
            type(value) == 'string'
            and not value:lower():find('rc')
            and not value:lower():find('alpha')
            and not value:lower():find('beta')
        then
            parsed = version(value)
        end

        local problem = not parsed and clean(result.error or 'Release response could not be interpreted') or nil

        if parsed then
            latest_cache[name] = { time = os.time(), version = parsed }
        end
        callback(parsed, problem)
    end)
end

---@param name string
---@param online boolean
---@param callback fun(result: table)
function M.check(name, online, callback)
    local runner = require('formatters')
    local ok, definition = pcall(runner.get_definition, name)
    local item = { name = name, status = 'unmanaged' }

    if not ok or not definition then
        item.status = ok and 'planned' or 'error'
        item.reason = clean(runner.load_errors[name] or definition or 'Formatter module is absent')
        finish(name, item, callback)
        return
    end

    item.executable = executable(definition)
    local entry = catalog.entries[name]

    if not entry then
        item.status = item.executable and 'unmanaged' or 'missing'
        item.reason = 'No package/version metadata registered'
        finish(name, item, callback)
        return
    end

    item.pin = entry.pin
    item.url = entry.url

    local function complete(installed, missing, problem)
        item.installed = installed
        item.reason = problem

        local function publish(latest, latest_error)
            item.latest = latest
            item.latest_error = latest_error

            if missing then
                item.status = 'missing'
            elseif not installed then
                item.status = 'unknown'
            elseif entry.pin and compare(installed, entry.pin) ~= 0 then
                item.status = 'incompatible'
            elseif entry.pin then
                item.status = 'pinned'
            elseif not latest then
                item.status = 'unknown'
            else
                local order = compare(installed, latest)
                item.status = order == 0 and 'current' or order < 0 and 'outdated' or 'newer'
            end

            finish(name, item, callback)
        end

        if online and M.options.check_latest then
            fetch_latest(name, entry, publish)
        else
            local cached = latest_cache[name]
            publish(cached and cached.version or nil)
        end
    end

    if not item.executable then
        complete(nil, true, 'Formatter runtime/executable is absent')
        return
    end

    for _, path in ipairs(entry.files or {}) do
        local stat = uv.fs_stat(path)
        if not stat or stat.type ~= 'file' then
            complete(nil, true, 'Required file is absent: ' .. path)
            return
        end
    end

    if entry.manifest then
        local manifest = read_json(entry.manifest)
        local installed = manifest and version(manifest.version)
        complete(installed, not manifest, not installed and 'Package manifest is absent or unreadable' or nil)
        return
    end

    if not entry.probe then
        complete(nil, false, 'Installed-version probe is not configured')
        return
    end

    local argv = entry.probe(item.executable)
    if vim.fn.executable(argv[1]) ~= 1 then
        complete(nil, false, 'Version-probe dependency is missing: ' .. argv[1])
        return
    end

    process.run(argv, {
        cwd = catalog.root,
        env = {
            NO_COLOR = '1',
            JAVA_TOOL_OPTIONS = '',
            JDK_JAVA_OPTIONS = '',
            _JAVA_OPTIONS = '',
        },
    }, function(result)
        local text = result.text
        if entry.build_info then
            text = text:match('\n%s*mod%s+%S+%s+(%S+)') or ''
        end
        complete(result.ok and version(text) or nil, false, not result.ok and clean(result.error or result.text) or nil)
    end)
end

local function names_for(bufnr, all)
    local runner = require('formatters')
    local found = {}

    if all then
        for name in pairs(runner.module_sources) do
            found[name] = true
        end
        for name in pairs(runner.definitions) do
            found[name] = true
        end
    else
        for _, stage in ipairs(runner.formatters_by_ft[vim.bo[bufnr].filetype] or {}) do
            for _, name in ipairs(type(stage) == 'table' and stage or { stage }) do
                found[name] = true
            end
        end
    end

    local names = vim.tbl_keys(found)
    table.sort(names)
    return names
end

local function terminal_install(name, plan)
    if installing then
        vim.notify('Another formatter installation is active')
        return
    end

    local review = vim.inspect({
        command = plan.argv,
        environment = plan.env or {},
        cwd = catalog.root,
    })

    vim.ui.select({ 'Cancel', 'Install / update' }, {
        prompt = name .. '\n' .. review,
    }, function(choice)
        if choice ~= 'Install / update' then
            return
        end
        if installing then
            return
        end
        if vim.fn.executable(plan.argv[1]) ~= 1 then
            vim.notify('Required installer is missing: ' .. plan.argv[1])
            return
        end

        installing = true
        vim.cmd('botright new')
        local job = vim.fn.jobstart(plan.argv, {
            term = true,
            cwd = catalog.root,
            env = plan.env,
            on_exit = function(_, code)
                vim.schedule(function()
                    installing = false
                    M.check(name, true, function(item)
                        vim.notify(name .. ': installer exit ' .. code .. '; ' .. item.status)
                    end)
                end)
            end,
        })

        if job <= 0 then
            installing = false
            vim.notify('Could not start installer', vim.log.levels.ERROR)
        end
    end)
end

local function offer_install(name, item)
    local entry = catalog.entries[name]
    if not entry then
        vim.notify('Register package metadata before installing ' .. name)
        return
    end

    local function user_install()
        local target = entry.pin or item.latest
        if not entry.install or not target then
            vim.notify(entry.instructions or 'No verified installation recipe')
            if entry.url then
                vim.ui.select({ 'Cancel', 'Open installation page' }, {
                    prompt = name,
                }, function(choice)
                    if choice == 'Open installation page' then
                        vim.ui.open(entry.url)
                    end
                end)
            end
            return
        end

        assert(target:match('^%d+%.%d+%.?%d*$'), 'Invalid target version')
        terminal_install(name, entry.install(target))
    end

    local function pacman(package_name)
        if not package_name:match('^[%w@+_.-]+$') then
            vim.notify('Invalid pacman package name')
            return
        end
        terminal_install(name, {
            argv = { 'sudo', 'pacman', '-Syu', package_name },
        })
    end

    -- Private JS/JAR dependencies must not be confused with their Node/JVM owner.
    if not entry.private and vim.fn.executable('pacman') == 1 then
        if item.executable then
            process.run({ 'pacman', '-Qoq', item.executable }, {
                cwd = catalog.root,
            }, function(result)
                local owner = result.ok and result.text:match('^%s*([^%s]+)%s*$')
                if owner then
                    pacman(owner)
                elseif item.executable:match('^/usr/') then
                    vim.notify(
                        'System executable is unmanaged by this installer; ' .. 'use its original package manager.'
                    )
                else
                    user_install()
                end
            end)
            return
        elseif entry.arch_package then
            pacman(entry.arch_package)
            return
        end
    end

    user_install()
end

local function choose_action(name, bufnr, all)
    M.check(name, true, function(item)
        vim.ui.select({
            'Close',
            'Install / update',
            'Show details',
            'Refresh menu',
        }, {
            prompt = name .. ': ' .. item.status,
        }, function(choice)
            if choice == 'Install / update' then
                offer_install(name, item)
            elseif choice == 'Show details' then
                vim.notify(vim.inspect(item))
            elseif choice == 'Refresh menu' then
                M.menu(bufnr, all)
            end
        end)
    end)
end

---@param bufnr? integer
---@param all? boolean
function M.menu(bufnr, all)
    bufnr = bufnr or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end

    local names = names_for(bufnr, all)
    vim.ui.select(names, {
        prompt = 'Native formatter tools',
        format_item = function(name)
            local item = M.results[name]
            return name .. ' — ' .. (item and item.status or 'not checked')
        end,
    }, function(name)
        if name then
            choose_action(name, bufnr, all)
        end
    end)
end

function M.check_buffer(bufnr, automatic)
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end

    for _, name in ipairs(names_for(bufnr, false)) do
        M.check(name, true, function(item)
            local needs_attention = item.status == 'missing'
                or item.status == 'outdated'
                or item.status == 'incompatible'

            if automatic and needs_attention and catalog.entries[name] and not prompted[name] and not prompt_open then
                prompted[name] = true
                prompt_open = true
                vim.ui.select({ 'Later', 'Review tools' }, {
                    prompt = name .. ': ' .. item.status,
                }, function(choice)
                    prompt_open = false
                    if choice == 'Review tools' then
                        M.menu(bufnr, false)
                    end
                end)
            end
        end)
    end
end

function M.setup()
    vim.fn.mkdir(catalog.root, 'p', '700')
    vim.fn.mkdir(catalog.paths[1], 'p', '700')

    local separator = vim.fn.has('win32') == 1 and ';' or ':'
    local existing = vim.env.PATH or ''
    local additions = {}

    for _, path in ipairs(catalog.paths) do
        if
            not vim.tbl_contains(
                vim.split(existing, separator, {
                    plain = true,
                }),
                path
            )
        then
            additions[#additions + 1] = path
        end
    end
    if #additions > 0 then
        vim.env.PATH = table.concat(additions, separator) .. separator .. existing
    end
    api.nvim_create_user_command('FormatTools', function(command)
        M.menu(api.nvim_get_current_buf(), command.bang)
    end, { bang = true, desc = 'Choose formatter tools for buffer', force = true })

    api.nvim_create_user_command('FormatToolCheck', function()
        M.check_buffer(api.nvim_get_current_buf(), false)
    end, { desc = 'Check formatter tool availability', force = true })

    local group = api.nvim_create_augroup('FormatterToolMenus', {
        clear = true,
    })

    api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(event)
            if M.options.auto_prompt then
                vim.schedule(function()
                    M.check_buffer(event.buf, true)
                end)
            end
        end,
    })
end

return M
