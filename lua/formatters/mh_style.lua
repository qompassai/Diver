-- #################################################################
-- ~/.config/nvim/lua/formatters/mh_style.lua
-- Qompass AI Diver MH Style Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/florianschanda/miss_hit
---
--- A style checker and tidy-up robot for MATLAB and Octave code,
--- from the MISS_HIT toolkit (MATLAB Independent, Small & Safe,
--- High Integrity Tools). `mh_style --fix <file>` fixes the style
--- problems in the given file in place, so the runner hands it a
--- private copy of the buffer and reads the tidied result back
--- from that copy.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return {
        '--fix',
        assert(context.tempfile),
    }
end

---@type FormatterSpec
return {
    cmd = 'mh_style',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'm',
    decode = nil,
    pre_transform = nil,
}
