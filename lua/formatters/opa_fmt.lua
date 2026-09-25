-- #################################################################
-- ~/.config/nvim/lua/formatters/opa_fmt.lua
-- Qompass AI Diver Opa Fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://v0-63-0--opa-docs.netlify.app/cli/
---
--- OPA is the Open Policy Agent; `opa fmt` formats Rego policy
--- files. With no file argument it reads the policy from stdin and
--- prints the formatted policy to stdout.

---@type FormatterSpec
return {
    cmd = 'opa',
    args = { 'fmt' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'rego',
}
