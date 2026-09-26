-- #################################################################
-- ~/.config/nvim/lua/formatters/rumdl_fmt.lua
-- Qompass AI Diver rumdl fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/rvben/rumdl
---
--- ELI5: rumdl is a Markdown linter and formatter written in Rust.
--- `rumdl fmt --silent -` reads your Markdown from stdin; `--silent`
--- keeps its opinions off stdout so the runner gets back only the
--- formatted document (without it, leftover diagnostics could leak
--- into your buffer).

---@type FormatterSpec
return {
    cmd = 'rumdl',
    args = { 'fmt', '--silent', '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'rumdl.toml', '.rumdl.toml', 'pyproject.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'md',
    decode = nil,
    pre_transform = nil,
}
