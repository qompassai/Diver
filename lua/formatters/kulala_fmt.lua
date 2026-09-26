-- #################################################################
-- ~/.config/nvim/lua/formatters/kulala_fmt.lua
-- Qompass AI Diver Kulala Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/mistweaverco/kulala-fmt/blob/HEAD/README.md
---
--- A tidy-up robot for `.http` files (the request files the
--- Kulala plugin runs). `kulala-fmt format --stdin <path>` reads
--- the request from standard input, prints the tidied version to
--- standard output, and uses the path only as a name for the
--- buffer, never as a write target.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename ~= '' and context.filename or 'request.http'
    return {
        'format',
        '--stdin',
        name,
    }
end

---@type FormatterSpec
return {
    cmd = 'kulala-fmt',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'http',
    decode = nil,
    pre_transform = nil,
}
