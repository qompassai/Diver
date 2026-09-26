-- #################################################################
-- ~/.config/nvim/lua/formatters/nginxfmt.lua
-- Qompass AI Diver Nginxfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/nginxfmt/nginxfmt/blob/HEAD/README.md
---
--- nginxfmt formats nginx configuration files. The `-` argument
--- selects stdin, and the formatted config is printed to stdout.

---@type FormatterSpec
return {
    cmd = 'nginxfmt',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'conf',
}
