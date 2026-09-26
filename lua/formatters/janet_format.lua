-- #################################################################
-- ~/.config/nvim/lua/formatters/janet_format.lua
-- Qompass AI Diver Janet Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/ilanpillemer/janetfmt
---
--- A tidy-up robot for Janet code (a small, friendly language that
--- looks a bit like Lisp). `janetfmt` reads a Janet file and prints
--- the tidied code to standard output, so the runner hands it a
--- private copy of the buffer and reads the answer back.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return {
        assert(context.tempfile),
    }
end

---@type FormatterSpec
return {
    cmd = 'janetfmt',
    args = build_args,
    mode = 'tempfile',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'janet',
    decode = nil,
    pre_transform = nil,
}
