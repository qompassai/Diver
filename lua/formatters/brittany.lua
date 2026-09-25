-- #################################################################
-- ~/.config/nvim/lua/formatters/brittany.lua
-- Native Brittany Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/lspitzner/brittany/blob/HEAD/README.md
---
--- Brittany is a code tidier for Haskell: it rewrites Haskell source code
--- with clean, consistent layout.
---
--- Its default mode needs no flags at all: with no file arguments it reads
--- the module from stdin and prints the tidied module to stdout. The README
--- documents exactly this: `brittany  # stdin -> stdout`.

---@type FormatterSpec
return {
    cmd = 'brittany',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'hs',
}
