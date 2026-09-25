-- #################################################################
-- ~/.config/nvim/lua/formatters/pint.lua
-- Qompass AI Diver Laravel Pint Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires the native formatters/init.lua supplied earlier, no plugin.
-- CLI reference: Laravel Pint v1.24.0 (https://github.com/laravel/pint).
--
---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
    local tempfile = context.tempfile
    if not tempfile or tempfile == '' then
        error('pint requires a private tempfile from the native formatter runner')
    end

    local args = {}
    args[#args + 1] = '--'
    args[#args + 1] = tempfile
    return args
end

---@type FormatterSpec
return {
    cmd = 'pint',
    args = arguments,
    mode = 'tempfile',
    output = 'file',
    cwd = working_directory,
    root_markers = {
        'pint.json',
        'composer.json',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'php',
}
