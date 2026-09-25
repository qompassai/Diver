-- #################################################################
-- ~/.config/nvim/lua/formatters/packer_fmt.lua
-- Qompass AI Diver Packer Fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://developer.hashiCorp.com/packer/docs/commands/fmt
---
--- `packer fmt` rewrites Packer HCL templates in the canonical style.
--- The `-` argument makes it read the template from stdin and print
--- the formatted template to stdout instead of rewriting files.

---@type FormatterSpec
return {
    cmd = 'packer',
    args = { 'fmt', '-' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'pkr.hcl',
}
