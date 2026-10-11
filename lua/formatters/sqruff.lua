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
    allow_empty = false,
    args = { 'fix', '-' },
    automatic = true,
    cmd = 'sqruff',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'sql',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'sqruff.toml', '.sqruff', '.git' },
}
