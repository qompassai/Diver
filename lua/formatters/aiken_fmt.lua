-- #################################################################
-- ~/.config/nvim/lua/formatters/aiken_fmt.lua
-- Native Aiken Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/aniadev/prettier-plugin-aiken/blob/HEAD/README.md
---
--- Aiken is the language people use to write smart contracts on Cardano.
--- `aiken fmt` is its built-in code tidier: it takes messy Aiken code and
--- rewrites it with clean, consistent spacing and indentation, the same way
--- for everyone.
---
--- `--stdin` tells it: "don't look for files on disk, read the code I hand
--- you through stdin instead, and print the tidied code back to stdout."
--- The prettier plugin's README documents this exact invocation.

---@type FormatterSpec
return {
    cmd = 'aiken',
    args = {
        'fmt',
        '--stdin',
    },
    mode = 'stdin',
    output = 'stdout',
    root_markers = {
        'aiken.toml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'ak',
}
