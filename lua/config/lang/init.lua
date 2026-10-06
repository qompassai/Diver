-- /qompassai/Diver/lua/config/lang/init.lua
-- Qompass AI Diver Language Config Init (lazy)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------------
--
-- Lazy loading: lang modules are required + set up on first FileType
-- event, not at startup. Nothing lang-specific runs until a buffer
-- of that language actually opens.
local M = {}

---Map of filetype -> lang module name (alphabetical by filetype).
---A module is required once, then its setup() called once (if present).
local filetype_modules = {
    apex = 'sf',
    arduino = 'arduino',
    bash = 'bash',
    c = 'c',
    cpp = 'cpp',
    css = 'css',
    elixir = 'elixir',
    go = 'go',
    javascript = 'js',
    javascriptreact = 'js',
    kotlin = 'kotlin',
    latex = 'latex',
    lua = 'lua',
    markdown = 'md',
    mojo = 'mojo',
    nix = 'nix',
    odin = 'odin',
    php = 'php',
    python = 'python',
    ruby = 'ruby',
    rust = 'rust',
    scala = 'scala',
    sh = 'bash',
    tex = 'latex',
    toml = 'toml',
    typescript = 'ts',
    typescriptreact = 'js',
    zig = 'zig',
}

local loaded = {}

local group = vim.api.nvim_create_augroup('diver_lang_lazy', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
    group = group,
    desc = 'Lazy-load lang module on first use',
    callback = function(args)
        local ft = args.match
        local modname = filetype_modules[ft]
        if not modname or loaded[modname] then
            return
        end
        loaded[modname] = true
        local ok, mod = pcall(require, 'config.lang.' .. modname)
        if not ok then
            vim.notify(('diver: failed to load lang module %s: %s'):format(modname, mod), vim.log.levels.ERROR)
            return
        end
        if type(mod) == 'table' and type(mod.setup) == 'function' then
            local ok_setup, err = pcall(mod.setup)
            if not ok_setup then
                vim.notify(('diver: lang module %s setup failed: %s'):format(modname, err), vim.log.levels.ERROR)
            end
        end
    end,
})

-- Coverage manifest generator: registers :LangCoverage (re-runnable).
local coverage_gen = require('config.lang.coverage_gen')
coverage_gen.setup()

return M
