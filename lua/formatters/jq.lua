-- #################################################################
-- ~/.config/nvim/lua/formatters/jq.lua
-- Qompass AI Diver Jq Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://jqlang.org/manual/
---
--- A tidy-up robot for JSON: `jq '.'` reads JSON from standard
--- input and prints it back pretty-printed to standard output.
--- The dot means "take everything as-is", so it is a pure
--- pretty-printer here.

---@type FormatterSpec
return {
    cmd = 'jq',
    args = { '.' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'json',
    decode = nil,
    pre_transform = nil,
}
