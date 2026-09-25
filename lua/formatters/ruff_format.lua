-- #################################################################
-- ~/.config/nvim/lua/formatters/ruff_format.lua
-- Qompass AI Diver ruff format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/astral-sh/ruff
---
--- ELI5: `ruff format` is the very fast Python formatter. The `-` at
--- the end tells it to read your code from stdin, and
--- `--stdin-filename` tells it the buffer's file name so it can find
--- the right `pyproject.toml` / `ruff.toml` rules for your project.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename
    if name == '' then
        name = 'buffer.py'
    end
    return {
        'format',
        '--stdin-filename',
        name,
        '-',
    }
end

---@type FormatterSpec
return {
    cmd = 'ruff',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'py',
    decode = nil,
    pre_transform = nil,
}
