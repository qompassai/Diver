-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Requiring this module stays cheap: only codeactions (a few user commands)
-- and ddx (one autocmd) are eager. Everything else below loads its suite on
-- first use, so Unreal tooling is never active while doing Salesforce work.
local api = vim.api

local M = {} ---@version JIT

local function safe_require(module)
    local ok, result = pcall(require, module)
    if not ok then
        vim.notify('Failed to load ' .. module .. ': ' .. tostring(result), vim.log.levels.WARN)
        return nil
    end
    return result
end

--- Build a loader that requires `modname` and runs `setup(mod)` exactly once,
--- however often the loader is called. Used for suites whose setup registers
--- user commands: the stub entry points below delete themselves and let the
--- real setup re-create them.
---@param modname string
---@param setup fun(mod: table)
---@return fun(): table
local function ensure(modname, setup)
    local done = false
    return function()
        local mod = require(modname)
        if not done then
            done = true
            setup(mod)
        end
        return mod
    end
end

-- ---- games ------------------------------------------------------------
-- :GamesDoctor and <Space>gd only run the read-only health probes, so they
-- need no setup. :Games needs the full suite: the stub deletes itself so the
-- real setup() can register the genuine :Games command, then opens the menu.
local load_games = ensure('games', function(g)
    g.setup()
end)

api.nvim_create_user_command('Games', function()
    vim.cmd('delcommand Games')
    load_games().show_menu()
end, {
    desc = 'Open a combined Aseprite/Godot/Redot/Unity/Unreal action menu',
})

api.nvim_create_user_command('GamesDoctor', function()
    vim.cmd('checkhealth games')
end, {
    desc = "Report every engine's resolved binary/root (Aseprite/Godot/Redot/Unity/Unreal)",
})

vim.keymap.set('n', '<Space>gd', function()
    vim.cmd('checkhealth games')
end, {
    desc = "Games: report every engine's resolved binary/root",
})

-- ---- android ----------------------------------------------------------
-- Suite setup registers :Android, :AndroidAction, per-action commands and the
-- <leader>a* keymaps. The stubs below load it on first use; opening an
-- Android project file does the same, so the per-action commands exist
-- without invoking :Android first.
local load_android = ensure('dev.apps.android', function(a)
    a.setup()
end)

api.nvim_create_user_command('Android', function()
    vim.cmd('delcommand Android')
    load_android().show_menu()
end, {
    desc = 'Open Android action menu',
})

--- Mirrors the keymaps from dev/android/commands.lua setup_keymaps(), which
--- stays the source of truth for what each key does.
local android_keymaps = {
    { key = 'r', action = 'run_debug',      desc = 'Android: Run debug' },
    { key = 'c', action = 'clean',          desc = 'Android: Clean project' },
    { key = 'b', action = 'build_release',  desc = 'Android: Build release' },
    { key = 'e', action = 'start_emulator', desc = 'Android: Start emulator' },
    { key = 'x', action = 'stop_emulator',  desc = 'Android: Stop emulator' },
    { key = 's', action = 'capture_screen', desc = 'Android: Capture screen' },
    { key = 'd', action = 'doctor',         desc = 'Android: Run doctor' },
}
for _, spec in ipairs(android_keymaps) do
    vim.keymap.set('n', '<leader>a' .. spec.key, function()
        load_android()
        require('dev.apps.android.actions').run_action_by_id(spec.action)
    end, {
        desc = spec.desc,
    })
end

api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    pattern = { 'AndroidManifest.xml', '*.gradle', '*.gradle.kts' },
    once = true,
    callback = function()
        load_android()
    end,
    desc = 'Lazy-load the Android tool suite in Android projects',
})

-- ---- salesforce -------------------------------------------------------
-- dev/sf/init.lua registers its commands and autocmds at require time, so
-- requiring it is sufficient. Trigger on the distinctive Salesforce file
-- types (mirrors the suite's own BufEnter patterns).
api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    pattern = { '*.apex', '*.cls', '*.trigger', '*/dev/sf/*.lua' },
    once = true,
    callback = function()
        require('dev.sf')
    end,
    desc = 'Lazy-load the Salesforce tool suite in Salesforce projects',
})

-- ---- salesforce stub + project detection --------------------------------
-- dev/sf/init.lua registers its commands at require time, so requiring it
-- is sufficient. :Sf loads the suite on demand and reports status; any
-- buffer inside an sfdx-project.json tree loads it for generic file types
-- (the suite's own autocmd above covers *.apex/*.cls/*.trigger).
local load_sf = ensure('dev.sf', function(_) end)

api.nvim_create_user_command('Sf', function()
    vim.cmd('delcommand Sf')
    local ok, sf = pcall(require, 'dev.sf')
    if not ok or type(sf) ~= 'table' or type(sf.core) ~= 'table' then
        vim.notify('Failed to load the Salesforce suite', vim.log.levels.ERROR)
        return
    end
    local core = sf.core
    local lines = { 'Salesforce suite loaded.' }
    if core.in_sf_project() then
        lines[#lines + 1] = 'Project: ' .. core.root()
    else
        lines[#lines + 1] = 'Not inside an sfdx project (no sfdx-project.json found).'
    end
    lines[#lines + 1] = 'sf CLI: ' .. (vim.fn.executable('sf') == 1 and 'available' or 'not in PATH')
    core.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end, {
    desc = 'Load the Salesforce tool suite and show project status',
})

api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    pattern = { '*' },
    callback = function(event)
        if package.loaded['dev.sf'] then
            return
        end
        local bufnr = event.buf
        if not api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then
            return
        end
        local name = api.nvim_buf_get_name(bufnr)
        if name == '' then
            return
        end
        local marker = vim.fs.find('sfdx-project.json', {
            path = vim.fs.dirname(name),
            type = 'file',
            upward = true,
            limit = 1,
        })
        if marker[1] then
            load_sf()
        end
    end,
    desc = 'Lazy-load the Salesforce suite in sfdx-project.json projects',
})

-- ---- cargo ------------------------------------------------------------
-- dev/cargo/init.lua registers its commands inside setup(). The stubs below
-- load it on first use; any buffer inside a Cargo.toml tree does the same,
-- so the :Cargo family exists without invoking :Cargo first.
local load_cargo = ensure('dev.cargo', function(c)
    c.setup()
end)

api.nvim_create_user_command('Cargo', function(cmd_opts)
    vim.cmd('delcommand Cargo')
    load_cargo().cmd_cargo(cmd_opts)
end, {
    nargs = '*',
    desc = 'Run cargo in a floating terminal (loads dev.cargo)',
})

api.nvim_create_user_command('CargoDocs', function(cmd_opts)
    vim.cmd('delcommand CargoDocs')
    load_cargo().cmd_docs(cmd_opts)
end, {
    desc = 'Open the Cargo Book (loads dev.cargo)',
})

api.nvim_create_user_command('CargoValidate', function(cmd_opts)
    vim.cmd('delcommand CargoValidate')
    load_cargo().cmd_validate(cmd_opts)
end, {
    desc = 'Cargo per-tool validation report (loads dev.cargo)',
})

api.nvim_create_user_command('CargoUpdateCheck', function(cmd_opts)
    vim.cmd('delcommand CargoUpdateCheck')
    load_cargo().cmd_update_check(cmd_opts)
end, {
    desc = 'Rust toolchain update check (loads dev.cargo)',
})

api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    pattern = { 'Cargo.toml', 'Cargo.lock' },
    once = true,
    callback = function()
        load_cargo()
    end,
    desc = 'Lazy-load the Cargo suite in Rust projects',
})

-- ---- still-eager small utils ------------------------------------------
M.codeactions = safe_require('utils.codeactions')

if M.codeactions and M.codeactions.setup then
    M.codeactions.setup()
end
M.ddx = require('utils.ddx')
M.dictionary = {
    path = vim.fn.stdpath('config') .. '/lua/research/dictionary',
    file = 'words.txt',
    load_words = function()
        local dict = vim.fn.stdpath('config') .. '/lua/research/dictionary/words.txt'
        local f = io.open(dict, 'r')
        if not f then
            vim.notify('Failed to open dictionary: ' .. dict, vim.log.levels.WARN)
            return {}
        end
        local t = {}
        for line in f:lines() do
            t[#t + 1] = line
        end
        f:close()
        return t
    end,
}

---Wire the eager utils suites. Called once from the top-level init.lua;
---kept here (rather than scattered leaf requires) so utils owns its children.
function M.setup()
    require('utils.nav').setup()
    require('utils.calendar').setup()
    require('utils.sync').setup()
    require('utils.snippets').setup()
    require('utils.tmux').setup({ keymaps_enabled = false })
    require('utils.notify').setup()
end

return M
