-- #################################################################
-- ~/.config/nvim/lua/formatters/sqruff.lua
-- Qompass AI Diver sqruff fix Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/quarylabs/sqruff
---
--- ELI5: sqruff is a very fast SQL formatter and linter written in
--- Rust. `sqruff fix -` reads your SQL from stdin and prints the
--- fixed SQL to stdout -- this is the documented way to plug it into
--- an editor as an external formatter.

---@type FormatterSpec
return {
    cmd = 'sqruff',
    args = { 'fix', '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'sqruff.toml', '.sqruff', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'sql',
    decode = nil,
    pre_transform = nil,
}
