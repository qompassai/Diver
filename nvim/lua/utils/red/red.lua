-- /qompassai/Diver/lua/utils/red/red.lua
-- Qompass AI Diver Red Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local uv = vim.uv or vim.loop
local function iter_files(root, exts)
    local handle = uv.fs_scandir(root)
    if not handle then
        return function() end
    end
    return function()
        while true do
            local name, t = uv.fs_scandir_next(handle)
            if not name then
                return
            end
            local path = root .. '/' .. name
            if t == 'directory' then
                for file in iter_files(path, exts) do
                    return file
                end
            else
                for _, ext in ipairs(exts) do
                    if name:sub(-#ext) == ext then
                        return path
                    end
                end
            end
        end
    end
end
local function scan_for_patterns(path, patterns)
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or type(lines) ~= 'table' then
        return {}
    end
    local findings = {}
    for i, line in ipairs(lines) do
        for _, p in ipairs(patterns) do
            if line:match(p.pattern) then
                table.insert(findings, {
                    file = path,
                    lnum = i,
                    severity = p.severity,
                    code = p.code,
                    message = p.message,
                })
            end
        end
    end
    return findings
end
local function add_findings_to_qf(findings, title)
    if #findings == 0 then
        vim.notify('[redteam] no issues found (' .. title .. ')', vim.log.levels.INFO)
        return
    end
    local items = {}
    for _, it in ipairs(findings) do
        table.insert(items, {
            filename = it.file,
            lnum = it.lnum,
            col = 1,
            text = string.format('[%s][%s] %s', it.severity, it.code, it.message),
        })
    end
    vim.fn.setqflist({}, ' ', {
        title = 'redteam: ' .. title,
        items = items,
    })
    vim.cmd('copen')
end
local function config_roots()
    return { vim.fn.stdpath('config'), vim.fn.stdpath('data') .. '/site/pack' }
end
local function check_static_patterns()
    local patterns = {
        {
            code = 'SYSTEM_CALL',
            message = [[vim.fn.system() call in config (review arguments and inputs)]],
            pattern = 'vim%.fn%.system%(',
            severity = 'warn',
        },
        {
            code = 'OS_EXECUTE',
            message = [[os.execute() call in config (consider safer alternatives)]],
            pattern = 'os%.execute%(',
            severity = 'warn',
        },
        {
            pattern = 'vim%.loop%.spawn%(',
            severity = 'warn',
            code = 'UV_SPAWN',
            message = 'vim.loop.spawn() used; ensure inputs are validated',
        },
        {
            pattern = 'loadstring%(',
            severity = 'warn',
            code = 'LOADSTRING',
            message = 'loadstring() used; avoid dynamic code eval where possible',
        },
        {
            pattern = 'vim%.cmd%(%s*["\']source%s+',
            severity = 'info',
            code = 'SOURCE_CMD',
            message = 'vim.cmd(\'source ...\') in config; verify target path is trusted',
        },
        {
            code = 'MODELINE',
            message = 'modeline referenced; ensure modelines/modelineexpr are disabled or secured',
            pattern = 'modeline',
            severity = 'info',
        },
    }
    local findings = {}
    for _, root in ipairs(config_roots()) do
        for file in iter_files(root, { '.lua', '.vim' }) do
            vim.list_extend(findings, scan_for_patterns(file, patterns))
        end
    end
    add_findings_to_qf(findings, 'static-patterns')
end
local function check_modeline_state()
    local findings = {}
    local function add_if(option, expected, code, message)
        local val = vim.o[option]
        if val ~= expected then
            table.insert(findings, {
                file = '$OPTIONS',
                lnum = 0,
                severity = 'warn',
                code = code,
                message = string.format(
                    '%s is %s, expected %s (%s)',
                    option,
                    tostring(val),
                    tostring(expected),
                    message
                ),
            })
        end
    end
    add_if('modeline', false, 'MODEL_OPTION', 'disable modeline to reduce RCE surface')
    add_if('modelineexpr', false, 'MODEL_EXPR', 'disable modelineexpr (expressions in modelines)')
    add_findings_to_qf(findings, 'modeline-state')
end
local function harden_modelines()
    vim.o.modeline = false
    vim.o.modelineexpr = false
    vim.notify('[redteam] modelines disabled (modeline=false, modelineexpr=false)', vim.log.levels.WARN)
end
local function check_unpinned_vim_pack()
    local findings = {}
    local patterns = {
        {
            pattern = '{%s*src%s*=%s*["\']https://github%.com/[%w-_]+/[%w-_.]+["\']%s*}',
            severity = 'warn',
            code = 'UNPINNED_PLUGIN',
            message = 'vim.pack plugin with GitHub src and no explicit ref/commit; consider pinning',
        },
    }
    for _, root in ipairs(config_roots()) do
        for file in iter_files(root, { '.lua' }) do
            vim.list_extend(findings, scan_for_patterns(file, patterns))
        end
    end
    add_findings_to_qf(findings, 'vim-pack-unpinned')
end
local default_ai_patterns = {
    'copilot',
    'codeium',
    'claude',
    'openai',
    'gpt',
    'ai.nvim',
    'chatgpt',
}
local function check_remote_plugins(user_patterns)
    local patterns = user_patterns or default_ai_patterns
    local roots = {
        vim.fn.stdpath('data') .. '/site/pack',
        vim.fn.stdpath('data') .. '/lazy',
    }
    local findings = {}
    for _, root in ipairs(roots) do
        local handle = uv.fs_scandir(root)
        if handle then
            while true do
                local name, t = uv.fs_scandir_next(handle)
                if not name then
                    break
                end
                local path = root .. '/' .. name
                if t == 'directory' then
                    for _, pat in ipairs(patterns) do
                        if name:lower():match(pat) then
                            table.insert(findings, {
                                file = path,
                                lnum = 0,
                                severity = 'info',
                                code = 'REMOTE_PLUGIN',
                                message = [[plugin matches remote/AI pattern ']]
                                    .. pat
                                    .. [['; review data exfiltration/privacy settings]],
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    add_findings_to_qf(findings, 'remote-plugins')
end
function M.run_all(opts)
    opts = opts or {}
    check_static_patterns()
    check_modeline_state()
    check_unpinned_vim_pack()
    if opts.detect_remote ~= false then
        check_remote_plugins(opts.remote_patterns)
    end
end

function M.audit_static()
    check_static_patterns()
end

function M.audit_modelines()
    check_modeline_state()
end

function M.audit_vim_pack()
    check_unpinned_vim_pack()
end

function M.audit_remote(opts)
    opts = opts or {}
    check_remote_plugins(opts.remote_patterns)
end

function M.harden_modelines()
    harden_modelines()
end

return M