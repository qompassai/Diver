-- #################################################################
-- ~/.config/nvim/lua/formatters/cl_format.lua
-- Native clfmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/fosskers/clfmt
---
--- clfmt is a code tidier for Common Lisp: it rewrites Lisp code with clean,
--- consistent indentation and spacing.
---
--- With no arguments it reads code from stdin and prints the tidied code to
--- stdout. (`-i` would edit a file in place, which we never want here.) The
--- adapter keeps the `cl_format` name while invoking the real `clfmt` binary.

---@type FormatterSpec
return {
    cmd = 'clfmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'lisp',
}
