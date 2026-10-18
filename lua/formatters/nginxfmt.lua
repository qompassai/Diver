-- ~/.config/nvim/lua/formatters/nginxfmt.lua
-- Qompass AI Diver Nginxfmt Native Formatter Spec
---@module 'formatters.nginxfmt'
---@source https://github.com/nginxfmt/nginxfmt/blob/HEAD/README.md
---
--- nginxfmt formats nginx configuration files. The `-` argument
--- selects stdin, and the formatted config is printed to stdout.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { '-' },
    automatic = true,
    cmd = 'nginxfmt',
    exit_codes = { 0 },
    extension = 'conf',
    mode = 'stdin',
    output = 'stdout',
}
