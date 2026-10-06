-- /qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
-- A2A SDK: <LocalLeader>aa* maps (card/send/stream/get/cancel/install)
-- are wired for this filetype by ai.a2a.sdks.setup().
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local formatters = require('formatters')
local modernize = require('config.lang.modernize')
local group = api.nvim_create_augroup('Python', {
    clear = true,
})
local log = vim.log
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.py',
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
formatters.register_stage({
    name = 'python_lsp_format',
    priority = 430,
    patterns = { '*.py' },
    desc = 'Format Python sources with ruff before save',
    run = function(bufnr)
        lsp.buf.format({
            async = false,
            bufnr = bufnr,
            filter = function(client)
                return client.name == 'ruff_ls'
            end,
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
            cmd.write()
            notify('Python code linted and formatted', log.levels.INFO)
        end, {})

        api.nvim_buf_create_user_command(0, 'PyTestFile', function()
            local file = fn.expand('%:p')
            cmd('split | terminal pytest ' .. fn.shellescape(file))
        end, {})
        api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
            local file = fn.expand('%:p')
            local pytcmd = 'pytest ' .. fn.shellescape(file) .. '::' .. fn.shellescape(fn.expand('<cword>')) .. ' -v'
            cmd('split | terminal ' .. pytcmd)
        end, {})
    end,
})
api.nvim_create_autocmd('LspAttach', {
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
---Create a buffer-local user command when a Python buffer opens.
---Lang commands only exist in buffers of their own language: they never
---pollute `:` completion elsewhere.
---@param name string command name
---@param fn function|string command implementation
---@param opts? table nvim_create_user_command options
local function buf_command(name, fn, opts)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'python',
        desc = ('Buffer-local command: %s'):format(name),
        callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, name, fn, opts or {})
        end,
    })
end

buf_command('PyHostPing', function()
    local chan = M.start()
    if not chan then
        return
    end
    local ok, res = pcall(vim.rpcrequest, chan, 'nvim_eval', '"pyhost:ok"')
    if ok then
        notify('Python host responded: ' .. tostring(res), log.levels.INFO)
    else
        notify('Python host ping failed: ' .. tostring(res), log.levels.ERROR)
    end
end, { desc = 'Ping the Python host process' })
---Resolve the Python interpreter for a buffer, reusing dap.python's
---resolver so DAP and LSP agree. Falls back to python3.
---@param bufnr integer
---@return string
local function resolve_python(bufnr)
    local ok, dap_py = pcall(require, 'dap.python')
    if ok and dap_py and dap_py.interpreter then
        local interp = dap_py.interpreter()
        if interp and interp ~= '' then
            return interp
        end
    end
    return 'python3'
end

buf_command('PyVenv', function()
    local bufnr = api.nvim_get_current_buf()
    local py = resolve_python(bufnr)
    vim.b[bufnr].python_path = py
    notify(('Python interpreter: %s'):format(py), log.levels.INFO)
end, { desc = 'Show the resolved Python interpreter for this buffer' })

---Point basedpyright at the resolved interpreter on attach, so it never
---silently type-checks against the wrong environment.
api.nvim_create_autocmd('LspAttach', {
    group = group,
    desc = 'Set basedpyright pythonPath from the resolved interpreter',
    callback = function(args)
        local client = lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'basedpyright' then
            return
        end
        local py = resolve_python(args.buf)
        client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
            python = { pythonPath = py },
        })
        client.notify('workspace/didChangeConfiguration', { settings = client.settings })
    end,
})

function M.start()
    if M.chan and fn.chanclose then
        
local REPLACEMENTS = {
    { "\\basyncio\\.coroutine\\b", "async def" },
    { "\\bcollections\\.Mapping\\b", "collections.abc.Mapping" },
    { "\\bcollections\\.Sequence\\b", "collections.abc.Sequence" },
    { "\\btime\\.clock\\s*\\(", "time.perf_counter(" },
}

---Modernize deprecated python syntax in the current buffer.
function M.modernize()
    modernize.buffer('python', REPLACEMENTS, 'python')
end

return M.chan
    end
    local script = fn.stdpath('config') .. '/scripts/host.py'
    if fn.filereadable(script) == 0 then
        notify('Python RPC host script not found: ' .. script, log.levels.ERROR)
        return nil
    end
    local pycmd = {
        'python3',
        script,
    }
    local chan = fn.jobstart(pycmd, {
        rpc = true,
        on_exit = function(_, code, _)
            if code ~= 0 then
                schedule(function()
                    notify('Python RPC host exited with code ' .. code, log.levels.WARN)
                end)
            end
            M.chan = nil
        end,
    })
    if chan <= 0 then
        notify('Failed to start Python RPC host', log.levels.ERROR)
        return nil
    end
    M.chan = chan
    return chan
end

return M
