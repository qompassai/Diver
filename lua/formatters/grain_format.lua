-- #################################################################
-- ~/.config/nvim/lua/formatters/grain_format.lua
-- Qompass AI Diver Grain Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/grain-lang/grain-lang.org/blob/HEAD/src_blog/_posts/Grain-Formatter.md
---
--- Grain's own tidy-up robot: `grain format <file>` reads the given
--- Grain file and prints it back in the one official Grain style to
--- standard output, leaving the file untouched. A file argument is
--- required; grain has no stdin mode, so the buffer is staged to a
--- temporary `.gr` file first.

---@type FormatterSpec
return {
    cmd = 'grain',
    args = function(context)
        return { 'format', context.tempfile }
    end,
    mode = 'tempfile',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'gr',
    decode = nil,
    pre_transform = nil,
}
