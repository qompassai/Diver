-- #################################################################
-- ~/.config/nvim/lua/formatters/ktlint.lua
-- Qompass AI Diver Ktlint Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/pinterest/ktlint/discussions/3149
---
--- A tidy-up robot for Kotlin. `-F` means "fix the style problems
--- you find", `--stdin` makes it read the code from standard
--- input and print the tidied result to standard output, and
--- `--stdin-path` tells it which file name to pretend the input
--- came from (so .editorconfig rules still apply).

---@param context FormatterContext
---@return string
local function working_directory(context)
    if context.filename ~= '' then
        local directory = vim.fs.dirname(context.filename)
        if directory then
            return directory
        end
    end
    return context.root
end

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename ~= '' and context.filename or 'file.kt'
    return {
        '-F',
        '--stdin',
        '--stdin-path=' .. name,
    }
end

---@type FormatterSpec
return {
    cmd = 'ktlint',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {},
    root_markers = { '.editorconfig', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'kt',
    decode = nil,
    pre_transform = nil,
}
