-- /qompassai/Diver/lua/config/lang/scala.lua
-- Qompass AI Diver Scala Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {} ---@version 5.1, JIT
local api = vim.api
local bo = vim.bo
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local bufgm = vim.api.nvim_buf_get_mark
local bufsl = vim.api.nvim_buf_set_lines
local client_by_id = vim.lsp.get_client_by_id
local cmd = vim.cmd
local code_action = vim.lsp.buf.code_action
local extend = vim.list_extend
local findfile = vim.fn.findfile
local ERROR = vim.log.levels.ERROR
local get = vim.diagnostic.get
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
local fn = vim.fn
local header = require('utils.docs.docs')
local group = augroup('Scala', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
local function buf_is_empty()
    return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.scala',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        bufsl(0, 0, 0, false, hdr)
        cmd('normal! G')
    end,
})
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.sc',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env -S scala-cli shebang'
        local hdr = header.make_header(filepath, '//')
        local lines = { shebang, '' }
        extend(lines, hdr)
        bufsl(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.scala',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        local lines = {}
        extend(lines, hdr)
        local filename = fn.expand('%:t')
        local is_test = filepath:match('/test/') or filename:match('Test%.scala$') or filename:match('Spec%.scala$')
        if is_test then
            extend(lines, {
                '',
                'import org.scalatest.flatspec.AnyFlatSpec',
                'import org.scalatest.matchers.should.Matchers',
                '',
                'class ' .. filename:gsub('%.scala$', '') .. ' extends AnyFlatSpec with Matchers {',
                '  ',
                '}',
            })
        else
            local package_path = filepath:match('src/main/scala/(.+)/')
            if package_path then
                local package = package_path:gsub('/', '.')
                extend(
                    lines,
                    { '', 'package ' .. package, '', 'object ' .. filename:gsub('%.scala$', '') .. ' {', '  ', '}' }
                )
            else
                extend(lines, {
                    '',
                    'object ' .. filename:gsub('%.scala$', '') .. ' {',
                    '  def main(args: Array[String]): Unit = {',
                    '    ',
                    '  }',
                    '}',
                })
            end
        end
        bufsl(0, 0, 0, false, lines)
        cmd('normal! G')
        fn.search('  $')
    end,
})
autocmd('FileType', {
    group = group,
    pattern = 'scala',
    callback = function(args)
        local bufnr = args.buf
        bo[bufnr].tabstop = 2
        bo[bufnr].shiftwidth = 2
        bo[bufnr].softtabstop = 2
        bo[bufnr].expandtab = true
        bo[bufnr].commentstring = '// %s'
    end,
})
autocmd('BufWritePre', {
    group = group,
    pattern = { '*.scala', '*.sc', '*.sbt' },
    callback = function(args)
        local diagnostics = get(args.buf)
        code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.organizeImports',
                    'source.fixAll',
                },
                triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
            },
            apply = true,
            filter = function(_, client_id)
                local client = client_by_id(client_id)
                return client ~= nil and client.name == 'metals'
            end,
        })
    end,
})
autocmd('BufWritePost', {
    group = group,
    pattern = { '*.scala', '*.sc', '*.sbt' },
    callback = function(args)
        local scalafmt_conf = findfile('.scalafmt.conf', '.;')
        if scalafmt_conf ~= '' and fn.executable('scalafmt') == 1 then
            jobstart({
                'scalafmt',
                '--non-interactive',
                '--quiet',
                api.nvim_buf_get_name(args.buf),
            }, {
                on_exit = function(_, code, _)
                    if code == 0 then
                        schedule(function()
                            cmd('e!')
                        end)
                    end
                end,
            })
        end
    end,
})
usercmd('ScalaCompile', function()
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        jobstart({ 'sbt', 'compile' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Scala compile successful', INFO)
                    else
                        notify('Scala compile failed', ERROR)
                    end
                end)
            end,
        })
    elseif build_sc ~= '' then
        jobstart({ 'mill', '__.compile' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Scala compile successful', INFO)
                    else
                        notify('Scala compile failed', ERROR)
                    end
                end)
            end,
        })
    else
        local current_file = fn.expand('%:p')
        jobstart({ 'scalac', current_file }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Scala compile successful', INFO)
                    else
                        notify('Scala compile failed', ERROR)
                    end
                end)
            end,
        })
    end
end, {})
usercmd('ScalaRun', function()
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        cmd('terminal sbt run')
    elseif build_sc ~= '' then
        cmd('terminal mill __.run')
    else
        local current_file = fn.expand('%:p')
        cmd('terminal scala ' .. current_file)
    end
end, {})
usercmd('ScalaTest', function(opts)
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        if opts.args ~= '' then
            jobstart({ 'sbt', 'testOnly ' .. opts.args }, { detach = false })
        else
            local current_file = fn.expand('%:p')
            if current_file:match('/test/') then
                local test_class = fn.expand('%:t:r')
                local package_path = current_file:match('src/test/scala/(.+)%.scala$')
                if package_path then
                    local fqn = package_path:gsub('/', '.')
                    jobstart({ 'sbt', 'testOnly ' .. fqn }, { detach = false })
                elseif test_class ~= '' then
                    jobstart({ 'sbt', 'testOnly *' .. test_class }, { detach = false })
                else
                    jobstart({ 'sbt', 'test' }, { detach = false })
                end
            else
                jobstart({ 'sbt', 'test' }, { detach = false })
            end
        end
    elseif build_sc ~= '' then
        if opts.args ~= '' then
            jobstart({ 'mill', opts.args .. '.test' }, { detach = false })
        else
            jobstart({ 'mill', '__.test' }, { detach = false })
        end
    else
        notify('No build tool found (sbt/mill)', ERROR)
    end
end, {
    nargs = '?',
})
usercmd('ScalaTestQuick', function()
    local build_sbt = findfile('build.sbt', '.;')
    if build_sbt ~= '' then
        jobstart({ 'sbt', 'testQuick' }, { detach = false })
    else
        notify('testQuick requires sbt', ERROR)
    end
end, {})
usercmd('ScalaConsole', function()
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        cmd('terminal sbt console')
    elseif build_sc ~= '' then
        cmd('terminal mill -i __.console')
    else
        cmd('terminal scala')
    end
end, {})
usercmd('ScalaRepl', function()
    cmd('terminal scala')
end, {})
usercmd('ScalaFormat', function()
    local current_file = fn.expand('%:p')
    local scalafmt_conf = findfile('.scalafmt.conf', '.;')
    if scalafmt_conf == '' then
        notify('.scalafmt.conf not found', ERROR)
        return
    end
    if fn.executable('scalafmt') ~= 1 then
        notify('scalafmt not found', ERROR)
        return
    end
    jobstart({
        'scalafmt',
        current_file,
    }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Scalafmt successful', INFO)
                    cmd('e!')
                else
                    notify('Scalafmt failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('ScalaClean', function()
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        jobstart({ 'sbt', 'clean' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('sbt clean successful', INFO)
                    else
                        notify('sbt clean failed', ERROR)
                    end
                end)
            end,
        })
    elseif build_sc ~= '' then
        jobstart({ 'mill', 'clean' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('mill clean successful', INFO)
                    else
                        notify('mill clean failed', ERROR)
                    end
                end)
            end,
        })
    else
        notify('No build tool found (sbt/mill)', ERROR)
    end
end, {})
usercmd('ScalaPackage', function()
    local build_sbt = findfile('build.sbt', '.;')
    local build_sc = findfile('build.sc', '.;')
    if build_sbt ~= '' then
        jobstart({ 'sbt', 'package' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('sbt package successful', INFO)
                    else
                        notify('sbt package failed', ERROR)
                    end
                end)
            end,
        })
    elseif build_sc ~= '' then
        jobstart({ 'mill', '__.jar' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('mill jar successful', INFO)
                    else
                        notify('mill jar failed', ERROR)
                    end
                end)
            end,
        })
    else
        notify('No build tool found (sbt/mill)', ERROR)
    end
end, {})
usercmd('ScalaUpdate', function()
    local build_sbt = findfile('build.sbt', '.;')
    if build_sbt ~= '' then
        jobstart({ 'sbt', 'update' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Dependencies updated', INFO)
                    else
                        notify('Dependency update failed', ERROR)
                    end
                end)
            end,
        })
    else
        notify('sbt not found', ERROR)
    end
end, {})
usercmd('ScalaMetalsBuild', function()
    local clients = vim.lsp.get_clients({ name = 'metals', bufnr = 0 })
    if clients[1] then
        clients[1]:exec_cmd({ command = 'metals.build-import' })
    else
        notify('Metals client not found', ERROR)
    end
end, {})
usercmd('ScalaMetalsConnect', function()
    local clients = vim.lsp.get_clients({ name = 'metals', bufnr = 0 })
    if clients[1] then
        clients[1]:exec_cmd({ command = 'metals.build-connect' })
    else
        notify('Metals client not found', ERROR)
    end
end, {})
usercmd('ScalaQuickfix', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
            },
            triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
    })
end, {})
usercmd('ScalaCodeAction', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix', 'refactor', 'source.organizeImports', 'source.fixAll' },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'metals'
        end,
        apply = true,
    })
end, {})
usercmd('ScalaRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = bufgm(bufnr, '<')
    local end_pos = bufgm(bufnr, '>')
    code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix', 'refactor.extract' },
        },
        range = {
            start = { start_pos[1], start_pos[2] },
            ['end'] = { end_pos[1], end_pos[2] },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'metals'
        end,
        apply = false,
    })
end, {
    range = true,
})

return M