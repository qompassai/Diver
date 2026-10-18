-- ~/.config/nvim/lua/formatters/powershell_formatter.lua
-- Qompass AI Diver Powershell Formatter Native Formatter Spec
---@module 'formatters.powershell_formatter'
---@source https://github.com/kjanat/powershell-formatter
---
--- This adapter is named powershell_formatter, but the upstream
--- project (kjanat/powershell-formatter) ships its CLI binary as
--- `psfmt` -- that is the real command used here. It reproduces
--- PSScriptAnalyzer's Invoke-Formatter behavior without starting a
--- PowerShell process. With no arguments psfmt is a stdin-to-stdout
--- filter. Exit code 4 is accepted on purpose: upstream defines it
--- as "malformed input passed through byte-identical", so the
--- buffer is never corrupted by a failed format.

---@type FormatterSpec
return {
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'psfmt',
    exit_codes = { 0, 4 },
    extension = 'ps1',
    mode = 'stdin',
    output = 'stdout',
}
