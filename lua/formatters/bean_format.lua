-- #################################################################
-- ~/.config/nvim/lua/formatters/bean_format.lua
-- Native bean-format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/beancount/beancount
---
--- Beancount is a plain-text accounting tool, and `bean-format` (shipped with
--- the Python beancount package) is its whitespace tidier. It lines up all
--- the money numbers in neat columns and left-aligns the currency names,
--- changing only whitespace — never the numbers themselves.
---
--- `-` means: "read the ledger from stdin and print the tidied ledger back
--- to stdout." The null-ls builtin documents `command = "bean-format"` with
--- `args = { "-" }` for exactly this pipe workflow; the upstream beancount
--- docs describe the same tool.

---@type FormatterSpec
return {
    cmd = 'bean-format',
    args = {
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'beancount',
}
