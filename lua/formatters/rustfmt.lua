-- #################################################################
-- ~/.config/nvim/lua/formatters/rustfmt.lua
-- Qompass AI Diver rustfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/rust-lang/rustfmt
---
--- ELI5: rustfmt is Rust's official code formatter. Called with no file
--- arguments it reads your code from stdin, and `--emit=stdout` makes
--- it print the formatted code instead of rewriting files. No
--- `--edition` flag is forced: rustfmt finds `rustfmt.toml` by itself,
--- and forcing an edition could fight your project's own config.

---@type FormatterSpec
return {
    cmd = 'rustfmt',
    args = { '--emit=stdout' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'rustfmt.toml', '.rustfmt.toml', 'Cargo.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'rs',
    decode = nil,
    pre_transform = nil,
}
