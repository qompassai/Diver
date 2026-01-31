-- /qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
local lsp = vim.lsp
local notify = vim.notify
local group = api.nvim_create_augroup('Python', {
    clear = true,
})
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = { '*.py' },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env python3'
        local hdr = header.make_header(filepath, '#')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.py',
    },
    callback = function(args)
        require('config.core.lint').lint({
            name = 'bandit',
            bufnr = args.buf,
        })
        require('config.core.lint').lint({
            name = 'vulture',
            bufnr = args.buf,
        })
    end,
})
api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'python',
    callback = function()
        api.nvim_buf_create_user_command(0, 'PythonLint', function()
            lsp.buf.format({
                filter = function(client)
                    return client.name == 'ruff_ls' or client.name == 'pyrefly_ls' or client.name == 'ty_ls'
                end,
            })
            vim.cmd.write()
            vim.notify('Python code linted and formatted', vim.log.levels.INFO)
        end, {})
        vim.api.nvim_buf_create_user_command(0, 'PyTestFile', function()
            local file = fn.expand('%:p')
            vim.cmd('split | terminal pytest ' .. file)
        end, {})
        api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
            local file = fn.expand('%:p')
            local cmd = 'pytest ' .. file .. '::' .. fn.expand('<cword>') .. ' -v'
            vim.cmd('split | terminal ' .. cmd)
        end, {})
    end,
})
api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.py',
    callback = function(args)
        lsp.buf.format({
            async = true,
            bufnr = args.buf,
            filter = function(client)
                return client.name == 'pyrefly_ls' or client.name == 'ruff_ls' or client.name == 'ty_ls'
            end,
        })
    end,
})
local blackd = {
    job = nil,
    count = 0,
}
local function start_blackd()
    if blackd.job then
        return
    end
    blackd.job = vim.system({
        'blackd',
        '--bind-host',
        '127.0.0.1',
        '--bind-port',
        '45484',
    }, {
        text = true,
    }, function(res)
        blackd.job = nil
        if res.code ~= 0 then
            vim.schedule(function()
                notify('blackd exited with code ' .. res.code, vim.log.levels.WARN)
            end)
        end
    end)
end
local function stop_blackd()
    if not blackd.job then
        return
    end
    blackd.job:kill('term')
    blackd.job = nil
end
api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'python',
    callback = function(args)
        blackd.count = blackd.count + 1
        if blackd.count == 1 then
            start_blackd()
        end
        api.nvim_create_autocmd('BufWipeout', {
            buffer = args.buf,
            once = true,
            callback = function()
                blackd.count = blackd.count - 1
                if blackd.count <= 0 then
                    blackd.count = 0
                    stop_blackd()
                end
            end,
        })
    end,
})
api.nvim_create_user_command('PyLintAll', function()
    local file = fn.expand('%:p')
    local cmds = {
        {
            'ruff',
            'check',
            file,
        },
        {
            'bandit',
            '-q',
            file,
        },
        {
            'vulture',
            file,
        },
        {
            'pyrefly',
            file,
        },
    }
    for _, cmd in ipairs(cmds) do
        if fn.executable(cmd[1]) == 1 then
            fn.jobstart(cmd, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' then
                        vim.schedule(function()
                            notify(table.concat(cmd, ' ') .. ': ' .. out, vim.log.levels.INFO)
                        end)
                    end
                end,
            })
        end
    end
end, {})
api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.py',
    callback = function(args)
        if fn.executable('blackd-client') == 0 then
            return
        end
        fn.jobstart({
            'blackd-client',
            api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            stderr_buffered = true,
        })
    end,
})
vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
        local client = lsp.get_client_by_id(args.data.client_id)
        if not client then
            return
        end
        if
            client.name == 'basedpyright'
            or client.name == 'pyrefly_ls'
            or client.name == 'ruff_ls'
            or client.name == 'ty_ls'
        then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
function M.start()
    if M.chan and fn.chanclose then
        return M.chan
    end
    local script = fn.stdpath('config') .. '/scripts/host.py'
    if fn.filereadable(script) == 0 then
        notify('Python RPC host script not found: ' .. script, vim.log.levels.ERROR)
        return nil
    end
    local cmd = {
        'python3',
        script,
    }
    local chan = fn.jobstart(cmd, {
        rpc = true,
        on_exit = function(_, code, _)
            if code ~= 0 then
                vim.schedule(function()
                    notify('Python RPC host exited with code ' .. code, vim.log.levels.WARN)
                end)
            end
            M.chan = nil
        end,
    })
    if chan <= 0 then
        notify('Failed to start Python RPC host', vim.log.levels.ERROR)
        return nil
    end
    M.chan = chan
    return chan
end

function M.setup_commands()
    api.nvim_create_user_command('PyHostPing', function()
        local chan = M.start()
        if not chan then
            return
        end
        local ok, res = pcall(vim.rpcrequest, chan, 'nvim_eval', '"pyhost:ok"')
        if ok then
            notify('Python host responded: ' .. tostring(res), vim.log.levels.INFO)
        else
            notify('Python host ping failed: ' .. tostring(res), vim.log.levels.ERROR)
        end
    end, {})
end

return M