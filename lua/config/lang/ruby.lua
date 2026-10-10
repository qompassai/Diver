-- /qompassai/Diver/lua/config/lang/ruby.lua
-- Qompass AI Diver Ruby Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version 5.1, JIT
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local client_by_id = vim.lsp.get_client_by_id
local cmd = vim.cmd
local code_action = vim.lsp.buf.code_action
local ERROR = vim.log.levels.ERROR
local findfile = vim.fn.findfile
local fn = vim.fn
local formatters = require('formatters')
local get = vim.diagnostic.get
local group = augroup('Ruby', {
    clear = true,
})
local header = require('research.docs')
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local modernize = require('config.lang.modernize')
local notify = vim.notify
local schedule = vim.schedule

---Publish the current gem to RubyGems. Dry-run by default: `gem build
---<gemspec>` only builds the .gem; nothing is uploaded. Use the bang form
---(:RubyPublish!) to also run `gem push` on the freshly built gem.
---Credentials stay in RubyGems' own chain (~/.gem/credentials); this
---hook never reads, stores, or logs them.
---@param bang boolean true to push the built gem for real
local function publish_package(bang)
    local dir = fn.expand('%:p:h')
    local spec = fn.glob(dir .. '/*.gemspec', false, true)[1]
    if not spec then
        notify('publish: no .gemspec found in ' .. dir, ERROR)
        return
    end
    local build = { 'gem', 'build', spec }
    notify('publish: ' .. table.concat(build, ' '), INFO)
    jobstart(build, {
        cwd = dir,
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if data then
                vim.schedule(function()
                    notify(table.concat(data, '\n'), INFO)
                end)
            end
        end,
        on_stderr = function(_, data, _)
            if data then
                vim.schedule(function()
                    notify(table.concat(data, '\n'), ERROR)
                end)
            end
        end,
        on_exit = function(_, code, _)
            if code ~= 0 or not bang then
                vim.schedule(function()
                    notify(('publish exited with code %d'):format(code), code == 0 and INFO or ERROR)
                end)
                return
            end
            local gems = fn.glob(dir .. '/*.gem', false, true)
            local newest, newest_time = nil, -1
            for _, gem_path in ipairs(gems) do
                local t = fn.getftime(gem_path)
                if t > newest_time then
                    newest, newest_time = gem_path, t
                end
            end
            if not newest then
                vim.schedule(function()
                    notify('publish: build succeeded but no .gem file found to push', ERROR)
                end)
                return
            end
            local push = { 'gem', 'push', newest }
            vim.schedule(function()
                notify('publish: ' .. table.concat(push, ' '), INFO)
            end)
            jobstart(push, {
                cwd = dir,
                stdout_buffered = true,
                on_stdout = function(_, data, _)
                    if data then
                        vim.schedule(function()
                            notify(table.concat(data, '\n'), INFO)
                        end)
                    end
                end,
                on_stderr = function(_, data, _)
                    if data then
                        vim.schedule(function()
                            notify(table.concat(data, '\n'), ERROR)
                        end)
                    end
                end,
                on_exit = function(_, push_code, _)
                    vim.schedule(function()
                        notify(('publish push exited with code %d'):format(push_code), push_code == 0 and INFO or ERROR)
                    end)
                end,
            })
        end,
    })
end

---Create a buffer-local user command when a ruby buffer opens.
---Lang commands only exist in buffers of their own language: they never
---pollute `:` completion elsewhere.
---@param name string command name
---@param callback function|string command implementation
---@param opts? table nvim_create_user_command options
local function usercmd(name, callback, opts)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'ruby',
        desc = ('Buffer-local command: %s'):format(name),
        callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, name, callback, opts or {})
        end,
    })
end

api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.rb',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env ruby'
        local hdr = header.make_header(filepath, '#')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})

autocmd('BufNewFile', {
    group = group,
    pattern = { '*.rb' },
    callback = function()
        local lines = api.nvim_buf_get_lines(0, 0, 1, false) ---@type string[]
        if lines[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p') ---@type string
        local hdr = header.make_header(filepath, '#')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        cmd('normal! G')
    end,
})

autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.rb',
        '*.rake',
        'Gemfile',
        'Rakefile',
    },
    callback = function(args)
        local rubocop = findfile('.rubocop.yml', '.;') --[[@as string]]
        if rubocop ~= '' then
            jobstart({
                'rubocop',
                '--format',
                'emacs',
                api.nvim_buf_get_name(args.buf),
            }, {
                stdout_buffered = true,
                on_stdout = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' and not out:match('^%s*$') then
                        schedule(function()
                            notify('rubocop: ' .. out, INFO)
                        end)
                    end
                end,
            })
        end
    end,
})

autocmd('FileType', {
    group = group,
    pattern = 'ruby',
    callback = function(args)
        local bufnr = args.buf
        vim.bo[bufnr].tabstop = 2
        vim.bo[bufnr].shiftwidth = 2
        vim.bo[bufnr].expandtab = true
        vim.bo[bufnr].commentstring = '# %s'
    end,
})

formatters.register_stage({
    name = 'ruby_organize_imports',
    priority = 431,
    patterns = {
        '*.rb',
        '*.rake',
        'Gemfile',
        'Rakefile',
        'config.ru',
    },
    desc = 'Organize imports in Ruby sources before save',
    run = function(bufnr)
        local diagnostics = get(bufnr)
        code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.organizeImports',
                    'source.fixAll',
                },
                triggerKind = lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = client_by_id(client_id)
                return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
            end,
        })
    end,
})

usercmd('RubyCodeAction', function()
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
            return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
        end,
        apply = true,
    })
end, {})

usercmd('RubyGems', function()
    jobstart({ 'bundle', 'install' }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Bundle install successful', INFO)
                else
                    notify('Bundle install failed', ERROR)
                end
            end)
        end,
    })
end, {})

usercmd('RubyIRB', function()
    cmd('terminal irb')
end, {})

usercmd('RubyPry', function()
    cmd('terminal pry')
end, {})

usercmd('RubyPublish', function(args)
    publish_package(args.bang)
end, { bang = true, desc = 'gem build (dry-run); :RubyPublish! also pushes to RubyGems' })

usercmd('RubyQuickfix', function()
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

usercmd('RubyRangeAction', function()
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
            return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
        end,
        apply = false,
    })
end, {
    range = true,
})

usercmd('RubyRubocop', function()
    local current_file = fn.expand('%:p')
    jobstart({
        'rubocop',
        '--auto-correct',
        current_file,
    }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('RuboCop auto-correct successful', INFO)
                    vim.cmd('e!')
                else
                    notify('RuboCop auto-correct failed', ERROR)
                end
            end)
        end,
    })
end, {})

usercmd('RubyRun', function()
    local current_file = fn.expand('%:p')
    jobstart({
        'ruby',
        current_file,
    }, { detach = true })
end, {})

usercmd('RubyTest', function()
    local current_file = fn.expand('%:p')
    local gemfile = findfile('Gemfile', '.;') --[[@as string]]

    if gemfile ~= '' then
        -- Check if using rspec or minitest
        local rspec_dir = fn.finddir('spec', '.;')
        if rspec_dir ~= '' then
            jobstart({
                'bundle',
                'exec',
                'rspec',
                current_file,
            }, { detach = false })
        else
            jobstart({
                'bundle',
                'exec',
                'ruby',
                current_file,
            }, { detach = false })
        end
    else
        jobstart({
            'ruby',
            current_file,
        }, { detach = false })
    end
end, {})

local REPLACEMENTS = {
    { '\\bDir\\.exists\\?', 'Dir.exist?' },
    { '\\bFile\\.exists\\?', 'File.exist?' },
}

---Modernize deprecated ruby syntax in the current buffer.
function M.modernize()
    modernize.buffer('ruby', REPLACEMENTS, 'ruby')
end

return M
