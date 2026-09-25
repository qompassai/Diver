-- #################################################################
-- ~/.config/nvim/lua/formatters/htmlbeautify.lua
-- Qompass AI Diver Htmlbeautify Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/threedaymonk/htmlbeautifier/blob/HEAD/README.md
---
--- A tidy-up robot for HTML (it also understands Ruby code hiding
--- inside Rails templates). Called with no file names, the
--- `htmlbeautifier` program reads HTML from standard input and
--- writes the nicely indented result to standard output.

---@type FormatterSpec
return {
    cmd = 'htmlbeautifier',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'html',
    decode = nil,
    pre_transform = nil,
}
