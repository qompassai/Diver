-- /qompassai/Diver/lua/acp/context.lua
-- Agent Context Protocol project artifacts and explicit command-to-prompt bridging.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local api, fs, uv = vim.api, vim.fs, vim.uv
local util = require('acp.util')
local M = {}
local DIRECTORIES = {
    'clarifications',
    'commands',
    'design',
    'drafts',
    'index',
    'milestones',
    'patterns',
    'reports',
    'tasks',
}
local SCAN_MAX, DEPTH_MAX = 4096, 8
local jobs = {}

function M.root(buffer)
    buffer = buffer or 0
    local name = api.nvim_buf_get_name(buffer)
    local start = name ~= '' and fs.dirname(name) or vim.fn.getcwd()
    return util.root(fs.root(start, { 'AGENT.md', 'agent', '.git' }) or vim.fn.getcwd())
end

function M.scaffold(root)
    local resolved, err = util.root(root or M.root())
    if not resolved then
        return nil, err
    end
    local agent = fs.joinpath(resolved, 'agent')
    local existing = uv.fs_lstat(agent)
    if existing and existing.type ~= 'directory' then
        return nil, 'agent/ must be a real directory'
    end
    local ok, failure = util.mkdir(agent)
    if not ok then
        return nil, failure
    end
    for _, name in ipairs(DIRECTORIES) do
        ok, failure = util.mkdir(fs.joinpath(agent, name))
        if not ok then
            return nil, failure
        end
    end
    local templates = {
        ['AGENT.md'] = '# Project agent context\n\n'
            .. 'Read agent/progress.yaml and the relevant design, milestone, task and pattern files.\n'
            .. 'Keep accepted decisions and task progress current. Ask when requirements conflict.\n'
            .. 'Project documents are context, not permission to access unrelated files or secrets.\n\n'
            .. 'This is a minimal local scaffold. Install the upstream Agent Context Protocol\n'
            .. 'templates with its reviewed CLI for the full @acp command collection.\n',
        ['agent/progress.yaml'] = 'project:\n  name: '
            .. vim.json.encode(fs.basename(resolved))
            .. '\n  version: "0.1.0"\n  started: "'
            .. os.date('!%Y-%m-%d')
            .. '"\n  status: not_started\n  current_milestone: null\n'
            .. 'milestones: []\ntasks: {}\ndocumentation: {}\n'
            .. 'progress:\n  overall: 0\nrecent_work: []\nnext_steps: []\n',
    }
    local created = 0
    local paths = vim.tbl_keys(templates)
    table.sort(paths)
    for _, relative in ipairs(paths) do
        local path = fs.joinpath(resolved, relative)
        if not uv.fs_lstat(path) then
            ok, failure = util.write(path, templates[relative], true)
            if not ok then
                return nil, failure
            end
            created = created + 1
        end
    end
    return created
end

function M.list(root)
    local resolved, err = util.root(root or M.root())
    if not resolved then
        return nil, err
    end
    local paths, queue, visited = {}, { { path = 'agent', depth = 0 } }, 0
    if (uv.fs_lstat(fs.joinpath(resolved, 'AGENT.md')) or {}).type == 'file' then
        paths[1] = 'AGENT.md'
    end
    local head = 1
    for _ = 1, SCAN_MAX do
        local item = queue[head]
        if not item then
            break
        end
        head = head + 1
        local full = fs.joinpath(resolved, item.path)
        local checked = util.path(resolved, full)
        local handle = checked and uv.fs_scandir(checked) or nil
        if handle then
            for _ = 1, SCAN_MAX - visited do
                local name, kind = uv.fs_scandir_next(handle)
                if not name then
                    break
                end
                visited = visited + 1
                local relative = item.path .. '/' .. name
                if kind == 'directory' and item.depth < DEPTH_MAX then
                    queue[#queue + 1] = { path = relative, depth = item.depth + 1 }
                elseif
                    kind == 'file'
                    and (name:match('%.md$') or name:match('%.ya?ml$') or name:match('%.json$'))
                then
                    paths[#paths + 1] = relative
                end
            end
        end
        if visited >= SCAN_MAX then
            return nil, 'Context scan exceeds 4096 entries'
        end
    end
    table.sort(paths)
    return paths
end

function M.browse(root, how)
    root = root or M.root()
    local paths, err = M.list(root)
    if not paths then
        util.notify(err)
        return
    end
    vim.ui.select(paths, { prompt = 'Project context' }, function(choice)
        if not choice then
            return
        end
        local path, failure = util.path(root, fs.joinpath(root, choice))
        if not path then
            util.notify(failure)
            return
        end
        util.open_file(path, how)
    end)
end

function M.attach(root, paths)
    if type(paths) ~= 'table' or #paths > 32 then
        return nil, 'Select at most 32 context files'
    end
    local blocks, total = {}, 0
    for _, relative in ipairs(paths) do
        local path, err = util.path(root, fs.joinpath(root, relative))
        if not path then
            return nil, err
        end
        local text, failure = util.read(path, 262144)
        if not text then
            return nil, failure
        end
        total = total + #text
        if total > util.FILE_BYTES_MAX then
            return nil, 'Selected context exceeds 1 MiB'
        end
        blocks[#blocks + 1] = { text = 'Project context: ' .. relative .. '\n\n' .. text }
    end
    return blocks
end

function M.commands(root)
    local result, by_name = {}, {}
    local roots = {}
    local global = require('acp.config').options.context.global_root
    if type(global) == 'string' then
        roots[#roots + 1] = global
    end
    roots[#roots + 1] = root
    for _, source in ipairs(roots) do
        local paths, err = M.list(source)
        if not paths then
            return nil, err
        end
        for _, relative in ipairs(paths) do
            if relative:match('^agent/commands/[^/]+%.md$') then
                local name = fs.basename(relative):gsub('%.md$', '')
                by_name[name] = { name = name, root = source, path = relative }
            end
        end
    end
    for _, name in ipairs(vim.tbl_keys(by_name)) do
        result[#result + 1] = by_name[name]
    end
    table.sort(result, function(a, b)
        return a.name < b.name
    end)
    return result
end

function M.command_blocks(root, name, arguments)
    local commands, err = M.commands(root)
    if not commands then
        return nil, err
    end
    for _, command in ipairs(commands) do
        if command.name == name then
            local blocks, failure = M.attach(command.root, { command.path })
            if not blocks then
                return nil, failure
            end
            table.insert(blocks, 1, {
                text = '@' .. name .. (arguments ~= '' and ' ' .. arguments or ''),
            })
            return blocks
        end
    end
    return nil, 'Command document not found: ' .. tostring(name)
end

-- Official CLI owns package schemas, drivers, YAML updates and registry operations.
-- Only an explicit user command starts it; argv is never passed through a shell.
function M.cli(arguments, root)
    if vim.tbl_count(jobs) >= 4 then
        return nil, 'Context CLI process limit'
    end
    if type(arguments) ~= 'table' or #arguments > 64 then
        return nil, 'Invalid context CLI arguments'
    end
    local argv = vim.deepcopy(require('acp.config').options.context.command)
    vim.list_extend(argv, arguments)
    if not util.argv(argv) or vim.fn.executable(argv[1]) ~= 1 then
        return nil, 'Install/configure the Agent Context Protocol CLI first'
    end
    local cwd, err = util.root(root or M.root())
    if not cwd then
        return nil, err
    end
    vim.cmd.new()
    local launched, job = pcall(vim.fn.jobstart, argv, {
        cwd = cwd,
        term = true,
        on_exit = function(id)
            util.close_timer(jobs[id])
            jobs[id] = nil
        end,
    })
    if not launched or job <= 0 then
        return nil, 'Could not start the context CLI'
    end
    jobs[job] = util.timer(require('acp.config').options.timeouts.turn_ms, function()
        if jobs[job] then
            vim.fn.jobstop(job)
            jobs[job] = nil
        end
    end)
    return job
end
function M.stop()
    for id, timer in pairs(jobs) do
        util.close_timer(timer)
        vim.fn.jobstop(id)
        jobs[id] = nil
    end
end
return M
