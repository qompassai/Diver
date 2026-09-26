-- #################################################################
-- ~/.config/nvim/lua/formatters/mbake.lua
-- Qompass AI Diver Mbake Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/ebodshojaei/bake/blob/HEAD/README.md
---
--- A tidy-up robot for Makefiles: it fixes tabs in recipes and
--- keeps spacing consistent. `mbake format <file>` rewrites the
--- given file in place, so the runner hands it a private copy of
--- the buffer and reads the tidied result back from that copy.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return {
        'format',
        assert(context.tempfile),
    }
end

---@type FormatterSpec
return {
    cmd = 'mbake',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = { 'Makefile', 'makefile', 'GNUmakefile', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'makefile',
    decode = nil,
    pre_transform = nil,
}
