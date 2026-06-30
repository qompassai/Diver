-- /qompassai/Diver/lua/mappings/utilmap.lua
-- Qompass AI Diver Utility Mappings Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@module 'mappings.utilmap'
local M = {}
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? string|table
local function map(mode, lhs, rhs, opts)
    local options = {
        silent = true,
        noremap = true,
    }
    if type(opts) == 'string' then
        options.desc = opts
    elseif type(opts) == 'table' then
        options = vim.tbl_extend('force', options, opts)
    end

    vim.keymap.set(mode, lhs, rhs, options)
end
local function create_user_command(name, rhs, desc)
    vim.api.nvim_create_user_command(name, rhs, {
        desc = desc,
    })
end
local function setup_terminal_mappings()
    map('t', '<Esc>', [[<C-\><C-n>]], 'Exit terminal mode')
    map('t', '<C-h>', [[<C-\><C-n><C-w>h]], 'Terminal window left')
    map('t', '<C-j>', [[<C-\><C-n><C-w>j]], 'Terminal window down')
    map('t', '<C-k>', [[<C-\><C-n><C-w>k]], 'Terminal window up')
    map('t', '<C-l>', [[<C-\><C-n><C-w>l]], 'Terminal window right')
    vim.api.nvim_create_autocmd({
        'TermOpen',
        'BufEnter',
    }, {
        pattern = 'term://*',
        desc = 'Enter insert mode in terminal buffers',
        callback = function()
            vim.cmd('startinsert')
        end,
    })
    create_user_command('AudioTerm', function()
        vim.cmd('botright 12split | terminal')
    end, 'Open utility terminal split')
    map('n', '<leader>zt', '<cmd>AudioTerm<cr>', 'Audio terminal')
end

local function setup_quickfix_mappings()
    map('n', '<leader>zo', '<cmd>copen<cr>', 'Quickfix open')
    map('n', '<leader>zc', '<cmd>cclose<cr>', 'Quickfix close')
    map('n', '<leader>zn', '<cmd>cnext<cr>', 'Quickfix next')
    map('n', '<leader>zp', '<cmd>cprevious<cr>', 'Quickfix previous')
    map('n', '<leader>zN', '<cmd>cnewer<cr>', 'Quickfix newer list')
    map('n', '<leader>zP', '<cmd>colder<cr>', 'Quickfix older list')
end
map('n', '<leader>ip', function()
    require('config.image').toggle()
end, 'Toggle image preview')
local function setup_audio_commands()
    vim.opt.makeprg = 'make'
    create_user_command('AudioPreview', 'make preview', 'Build audio preview target')
    create_user_command('AudioFinal', 'make final', 'Build final audio target')
    create_user_command('AudioPlay', function()
        vim.cmd('botright 12split | terminal mpv audio/preview.wav')
    end, 'Play audio preview in terminal split')
    create_user_command('AudioRenderCsound', function()
        vim.cmd('botright 12split | terminal csound -o audio/csound_layer.wav csd/texture.csd')
    end, 'Render CSound layer')
    map('n', '<leader>xr', '<cmd>AudioRenderCsound<cr>', 'Audio render CSound')
    map('n', '<leader>xf', '<cmd>AudioFinal<cr>', 'Audio final')
    map('n', '<leader>xp', '<cmd>AudioPlay<cr>', 'Audio play')
    map('n', '<leader>xv', '<cmd>AudioPreview<cr>', 'Audio preview')
end
local ok, fzf = pcall(require, 'fzf-lua')
if ok then
    vim.keymap.set('n', '<leader>?', function()
        fzf.keymaps()
    end, { desc = 'Keymap cheatsheet (fzf-lua)', silent = true, noremap = true })
end
local function setup_salesforce_commands()
    local function shellescape(path)
        return vim.fn.shellescape(path)
    end
    local function current_file()
        return vim.api.nvim_buf_get_name(0)
    end
    local function current_filetype()
        return vim.bo.filetype
    end

    local function current_basename()
        return vim.fn.expand('%:t:r')
    end
    local function open_term_cmd(cmd, height)
        height = height or 14
        vim.cmd('botright ' .. height .. 'split | terminal ' .. cmd)
    end
    local function notify(msg, level)
        vim.notify(msg, level or vim.log.levels.INFO, { title = 'Salesforce' })
    end
    local function executable(bin)
        return vim.fn.executable(bin) == 1
    end
    local function is_apex_script(file)
        return file:match('%.apex$') ~= nil
    end
    local function is_apex_metadata(file)
        return file:match('%.cls$') ~= nil or file:match('%.trigger$') ~= nil
    end
    local function lwc_bundle_dir(file)
        return file:match('(.*/lwc/[^/]+)')
    end
    create_user_command('SfApexRun', function()
        local file = current_file()
        if file == '' then
            notify('No current file', vim.log.levels.WARN)
            return
        end
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        open_term_cmd('sf apex run --file ' .. shellescape(file))
    end, 'Execute current .apex file as anonymous Apex')
    create_user_command('SfDeployFile', function()
        local file = current_file()
        if file == '' then
            notify('No current file', vim.log.levels.WARN)
            return
        end
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        open_term_cmd('sf project deploy start --source-dir ' .. shellescape(file))
    end, 'Deploy current Salesforce file')

    create_user_command('SfRetrieveFile', function()
        local file = current_file()
        if file == '' then
            notify('No current file', vim.log.levels.WARN)
            return
        end
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        open_term_cmd('sf project retrieve start --source-dir ' .. shellescape(file))
    end, 'Retrieve current Salesforce file')

    create_user_command('SfTailLog', function()
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        open_term_cmd('sf apex tail log --color', 16)
    end, 'Tail Salesforce Apex logs')
    create_user_command('SfOrgOpen', function()
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        vim.cmd('terminal sf org open')
    end, 'Open Salesforce org in browser')
    create_user_command('SfRunCurrentTestClass', function()
        local name = current_basename()
        local file = current_file()
        if file == '' then
            notify('No current file', vim.log.levels.WARN)
            return
        end
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end
        open_term_cmd('sf apex run test --tests ' .. shellescape(name) .. ' --synchronous --result-format human', 16)
    end, 'Run current Apex test class')

    create_user_command('SfSmart', function()
        local file = current_file()
        local ft = current_filetype()

        if file == '' then
            notify('No current file', vim.log.levels.WARN)
            return
        end
        if not executable('sf') then
            notify('sf CLI not found in PATH', vim.log.levels.ERROR)
            return
        end

        if ft == 'apex' and is_apex_script(file) then
            open_term_cmd('sf apex run --file ' .. shellescape(file))
            return
        end
        if ft == 'apex' and is_apex_metadata(file) then
            open_term_cmd('sf project deploy start --source-dir ' .. shellescape(file))
            return
        end
        local lwc_dir = lwc_bundle_dir(file)
        if lwc_dir then
            open_term_cmd('sf project deploy start --source-dir ' .. shellescape(lwc_dir))
            return
        end
        if file:match('/aura/') then
            local aura_dir = file:match('(.*/aura/[^/]+)')
            if aura_dir then
                open_term_cmd('sf project deploy start --source-dir ' .. shellescape(aura_dir))
                return
            end
        end
        open_term_cmd('sf project deploy start --source-dir ' .. shellescape(file))
    end, 'Smart Salesforce action for current file')
    map('n', '<leader>sa', '<cmd>SfApexRun<cr>', 'Salesforce run anonymous Apex file')
    map('n', '<leader>sd', '<cmd>SfDeployFile<cr>', 'Salesforce deploy current file')
    map('n', '<leader>sr', '<cmd>SfRetrieveFile<cr>', 'Salesforce retrieve current file')
    map('n', '<leader>sl', '<cmd>SfTailLog<cr>', 'Salesforce tail logs')
    map('n', '<leader>so', '<cmd>SfOrgOpen<cr>', 'Salesforce open org')
    map('n', '<leader>st', '<cmd>SfRunCurrentTestClass<cr>', 'Salesforce run current test class')
    map('n', '<leader>ss', '<cmd>SfSmart<cr>', 'Salesforce smart action')
end
M.setup_utilmap = function()
    setup_terminal_mappings()
    setup_quickfix_mappings()
    setup_audio_commands()
    setup_salesforce_commands()
end
return M
