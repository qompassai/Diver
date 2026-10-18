-- ~/.config/nvim/lua/formatters/rustfmt.lua
-- Qompass AI Diver rustfmt Native Formatter Spec
---@module 'formatters.rustfmt'
---@source https://github.com/rust-lang/rustfmt
---
--- ELI5: rustfmt is Rust's official code formatter. Called with no file
--- arguments it reads your code from stdin, and `--emit=stdout` makes
--- it print the formatted code instead of rewriting files. No
--- `--edition` flag is forced: rustfmt finds `rustfmt.toml` by itself,
--- and forcing an edition could fight your project's own config.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { '--emit=stdout' },
    automatic = true,
    cmd = 'rustfmt',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'rs',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'rustfmt.toml', '.rustfmt.toml', 'Cargo.toml', '.git' },
}
