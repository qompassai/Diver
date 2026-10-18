-- ~/.config/nvim/lua/formatters/muon_fmt.lua
-- Qompass AI Diver Muon Fmt Native Formatter Spec
---@module 'formatters.muon_fmt'
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
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'muon',
    exit_codes = { 0 },
    extension = 'meson',
    mode = 'tempfile',
    output = 'stdout',
}
