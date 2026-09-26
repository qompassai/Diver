-- #################################################################
-- ~/.config/nvim/lua/formatters/cue_fmt.lua
-- Native cue fmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://cuelang.org/docs/reference/command/cue-help-fmt/
---
--- cue is the toolkit for the CUE configuration language, and
--- `cue fmt` is its built-in tidier. Think of it like handing messy
--- handwriting to a very neat friend: the `-` means "read my text
--- from the pipe instead of a file", and cue hands back the same
--- text, neatly rewritten, on stdout. There are no style knobs to
--- turn; canonical CUE style is the only style it knows.

---@type FormatterSpec
return {
    cmd = 'cue',
    args = { 'fmt', '-' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'cue.mod', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'cue',
}
