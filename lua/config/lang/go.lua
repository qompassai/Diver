-- /qompassai/Diver/lua/config/lang/go.lua
-- Qompass AI Diver Go Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local client_by_id = vim.lsp.get_client_by_id
local code_action = vim.lsp.buf.code_action
local get = vim.diagnostic.get
local fn = vim.fn
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local notify = vim.notify
local function run_cached_gvm(cmd)
    local handle = io.popen('bash -c \'source ~/.gvm/scripts/gvm && ' .. cmd .. '\'')
    if not handle then
        return nil
    end
    local result = handle:read('*a')
    handle:close()
    return result and vim.trim(result) or nil
end
local function get_go_bin()
    return run_cached_gvm('which go') or 'go'
end
local function get_gopath()
    return run_cached_gvm('go env GOPATH') or os.getenv('GOPATH') or ''
end
local function get_go_version()
    return run_cached_gvm('go version') or ''
end
local header = require('utils.docs.docs')
local group = augroup('Go', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = { '*.go' },
    callback = function()
        local lines = api.nvim_buf_get_lines(0, 0, 1, false) ---@type string[]
        if lines[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p') ---@type string
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})
autocmd('BufWritePre', {
    group = group,
    pattern = '*.go',
    callback = function(args)
        lsp.buf.format({
            bufnr = args.buf,
            async = false,
        })
    end,
})
usercmd('GoTest', function()
    local go_bin = get_go_bin()
    jobstart({
        go_bin,
        'test',
        '-v',
        fn.expand('%:p:h'),
    }, {
        detach = false,
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if data then
                vim.schedule(function()
                    notify(table.concat(data, '\n'), INFO)
                end)
            end
        end,
    })
end, {})
usercmd('GoQuickfix', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
            },
            triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'gopls'
        end,
    })
end, {})
usercmd('GoCodeAction', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor',
                'source.organizeImports',
                'source.fixAll',
            },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'gopls'
        end,
        apply = true,
    })
end, {})
usercmd('GoRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = api.nvim_buf_get_mark(bufnr, '>')
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor.extract',
            },
        },
        range = {
            start = {
                start_pos[1],
                start_pos[2],
            },
            ['end'] = {
                end_pos[1],
                end_pos[2],
            },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'gopls'
        end,
        apply = false,
    })
end, {
    range = true,
})
autocmd('BufWritePre', {
    group = group,
    pattern = '*.go',
    callback = function(args)
        local diagnostics = get(args.buf)
        code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.organizeImports',
                    'source.fixAll',
                },
                triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = client_by_id(client_id)
                return client ~= nil and client.name == 'gopls'
            end,
        })
    end,
})
autocmd('BufWritePost', {
    group = group,
    pattern = '*.go',
    callback = function(args)
        jobstart({
            'golangci-lint',
            'run',
            '--fast',
            '--out-format=line-number',
            api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        notify('golangci-lint: ' .. out, INFO)
                    end)
                end
            end,
        })
    end,
})
function M.go_autocmds()
    usercmd('GoEnvInfo', function()
        for label, value in pairs({
            ['Go Binary'] = get_go_bin(),
            ['Go Version'] = get_go_version(),
            ['GOPATH'] = get_gopath(),
        }) do
            notify(string.format('%s: %s', label, value), INFO)
        end
    end, {})
end

local function go_dap()
    return require('dap')
end
function M.go_dap()
    ---@return string|nil
    function run_cached_gvm(cmd) ---@param cmd string
        local handle = io.popen('bash -c \'source ~/.gvm/scripts/gvm && ' .. cmd .. '\'')
        if not handle then
            return nil
        end
        local result = handle:read('*a')
        handle:close()
        return result and vim.trim(result) or nil
    end

    local function get_dlv_bin() ---@return string
        return run_cached_gvm('which dlv') or 'dlv'
    end
    local dap_go_ok, dap_go = pcall(require, 'dap-go')
    if dap_go_ok then
        dap_go.setup({
            delve = {
                path = get_dlv_bin(),
                initialize_timeout_sec = 20,
                port = '${port}',
            },
        })
    end
    local dapui_ok, dapui = pcall(require, 'dapui')
    if dapui_ok then
        dapui.setup()
        local dap = go_dap()
        local before = dap.listeners.before
        dap.listeners.after.event_initialized['dapui_config'] = function()
            dapui.open()
        end
        before.event_terminated['dapui_config'] = function()
            dapui.close()
        end
        before.event_exited['dapui_config'] = function()
            dapui.close()
        end
    end
end

usercmd('GoRun', function()
    local go_bin = get_go_bin()
    jobstart({
        go_bin,
        'run',
        fn.expand('%:p'),
    }, { detach = true })
end, {})
usercmd('GoBuild', function()
    local go_bin = get_go_bin()
    jobstart({
        go_bin,
        'build',
        fn.expand('%:p:h'),
    }, {
        on_exit = function(_, code, _)
            vim.schedule(function()
                if code == 0 then
                    notify('Build successful', INFO)
                else
                    notify('Build failed', vim.log.levels.ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('GoStaticcheck', function()
    fn.jobstart({
        'staticcheck',
        './...',
    }, {
        cwd = fn.expand('%:p:h'),
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if data then
                vim.schedule(function()
                    notify('staticcheck: ' .. table.concat(data, '\n'), INFO)
                end)
            end
        end,
    })
end, {})
---@param opts table|nil
function M.go_cfg(opts)
    opts = opts or {}
end

return M