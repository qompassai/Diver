-- #################################################################
-- ~/.config/nvim/lua/formatters/muon_fmt.lua
-- Qompass AI Diver Muon Fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://manpages.debian.org/unstable/muon-meson/muon-meson.1.en.html
---
--- muon is a from-scratch Meson implementation in C. Its `fmt`
--- subcommand pretty-prints a Meson build file. Without `-i` it
--- prints the formatted source to stdout and leaves the input file
--- untouched, so the runner hands it a throwaway copy and reads the
--- formatted text back from stdout. `muon fmt` takes file paths
--- only; it has no stdin mode upstream.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return { 'fmt', context.tempfile }
end

---@type FormatterSpec
return {
    cmd = 'muon',
    args = build_args,
    mode = 'tempfile',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'meson',
}
