-- #################################################################
-- ~/.config/nvim/lua/formatters/nomad_fmt.lua
-- Qompass AI Diver Nomad Fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://docs.hashicorp.com/nomad/commands/fmt
---
--- `nomad fmt` canonicalizes Nomad job specifications. The `-`
--- argument makes it read the job from stdin and print the formatted
--- job to stdout. Note: upstream has a long-standing quirk where
--- repeated stdin formatting can append an extra trailing newline
--- (hashicorp/nomad#20307); the adapter passes the bytes through
--- untouched rather than working around it.

---@type FormatterSpec
return {
    cmd = 'nomad',
    args = { 'fmt', '-' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'nomad',
}
