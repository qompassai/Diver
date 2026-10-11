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
    allow_empty = false,
    args = { 'fmt', '-' },
    automatic = true,
    cmd = 'packer',
    exit_codes = { 0 },
    extension = 'pkr.hcl',
    mode = 'stdin',
    output = 'stdout',
}
