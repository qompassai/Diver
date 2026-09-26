-- #################################################################
-- ~/.config/nvim/lua/formatters/mdformat.lua
-- Qompass AI Diver Mdformat Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://pypi.org/project/mdformat/
---
--- A tidy-up robot for Markdown that follows the CommonMark
--- rules. The lone `-` tells it to read the Markdown from
--- standard input and print the tidied result to standard output.

---@type FormatterSpec
return {
    cmd = 'mdformat',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'md',
    decode = nil,
    pre_transform = nil,
}
