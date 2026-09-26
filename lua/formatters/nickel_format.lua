-- #################################################################
-- ~/.config/nvim/lua/formatters/nickel_format.lua
-- Qompass AI Diver Nickel Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/nickel-lang/nickel
---
--- Nickel is a configuration language; `nickel format` rewrites the
--- given files in place with the canonical layout. The runner gives
--- it a throwaway copy and reads the rewritten copy back from disk.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return { 'format', context.tempfile }
end

---@type FormatterSpec
return {
    cmd = 'nickel',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'ncl',
}
