-- #################################################################
-- ~/.config/nvim/lua/formatters/fnlfmt.lua
-- Native fnlfmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://git.sr.ht/~technomancy/fnlfmt
---
--- fnlfmt tidies Fennel code (a small Lisp that compiles to Lua). The
--- lone `-` means "read the code from stdin and print the pretty
--- version to stdout", so the buffer never has to touch the disk.

---@type FormatterSpec
return {
    cmd = 'fnlfmt',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'fnl',
}
