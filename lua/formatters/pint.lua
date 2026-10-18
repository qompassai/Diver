-- ~/.config/nvim/lua/formatters/pint.lua
-- Qompass AI Diver Laravel Pint Native Formatter Spec
---@source https://github.com/laravel/pint

--- Laravel Pint — opinionated PHP formatting for the buffer.
---
--- Plain-language version: Pint is Laravel's PHP formatter. The adapter
--- copies the buffer to a private tempfile and runs `pint` on that copy
--- (the `--` keeps the path from being parsed as a flag). Pint's style
--- profile always comes from the project: `pint.json` is discovered from
--- the project root (see root_markers), and only when no config exists does
--- Pint fall back to its built-in Laravel preset. No extra flags are passed
--- because the project's own config is the pinned profile.
---@module 'formatters.pint'

-- Requires the native formatters/init.lua supplied earlier, no plugin.
-- CLI reference: Laravel Pint v1.24.0 (https://github.com/laravel/pint).
--
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

---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = arguments,
    automatic = true,
    cmd = 'pint',
    cwd = working_directory,
    decode = nil,
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    extension = 'php',
    mode = 'tempfile',
    output = 'file',
    pre_transform = nil,
    root_markers = {
        'pint.json',
        'composer.json',
        '.git',
    },
}
