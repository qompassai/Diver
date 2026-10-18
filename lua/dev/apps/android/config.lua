-- /qompassai/lua/dev/apps/android/config.lua
-- Qompass AI Config
---@module 'dev.apps.android.config'
local M = {}
M.group_order = {
    'Build & deploy',
    'Emulator',
    'Android Studio',
    'Device',
    'Project',
}

M.max_recent = 3

M.output_filetype = 'android-output'

M.recent_path = vim.fn.stdpath('data') .. '/android-nvim/recent.json'

M.search_ns = vim.api.nvim_create_namespace('android-nvim-search')

M.stderr_ns = vim.api.nvim_create_namespace('android-nvim-stderr')
return M
