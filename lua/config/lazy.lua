-- /qompassai/Diver/lua/config/lazy.lua
-- Qompass AI Diver Lazy Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system({
        'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo,
        lazypath
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            {'Failed to clone lazy.nvim:\n', 'ErrorMsg'}, {out, 'WarningMsg'},
            {'\nPress any key to exit...'}
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)
-- LazyFile
-- local events = {}

-- local function create_lazy_file_event()
--  local LazyEvent = require("lazy.core.handler.event")

--  LazyEvent.mappings["LazyFile"] = { id = "LazyFile", event = { "BufReadPost", "BufNewFile", "BufWritePre" } }
--  events.LazyFile = vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePre" }, {
--   callback = function()
--      vim.api.nvim_del_autocmd(events.LazyFile)
--      events.LazyFile = nil
--      vim.api.nvim_exec_autocmds("User", { pattern = "LazyFile" })
--    end,
--  })
-- end
-- create_lazy_file_event()
require('lazy').setup({
    debug = false,
    spec = {{'LazyVim/LazyVim'}, {import = 'plugins'}},
    defaults = {lazy = true, version = false},
    install = {colorscheme = {'tokyonight', 'habamax'}},
    checker = {enabled = false, notify = false},
    performance = {
        rtp = {
            disabled_plugins = {
                'gzip', -- 'matchit',
                -- 'matchparen',
                -- "netrwPlugin',
                'tarPlugin', 'tohtml', 'tutor', 'zipPlugin'
            }
        }
    }
})
