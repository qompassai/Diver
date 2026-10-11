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
    allow_empty = false,
    args = { 'fmt', '--silent', '-' },
    automatic = true,
    cmd = 'rumdl',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'md',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'rumdl.toml', '.rumdl.toml', 'pyproject.toml', '.git' },
}
