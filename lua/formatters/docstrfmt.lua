-- #################################################################
-- ~/.config/nvim/lua/formatters/docstrfmt.lua
-- Native docstrfmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/lilspazjoekp/docstrfmt/blob/HEAD/README.rst
---
--- docstrfmt tidies reStructuredText documents and docstrings. Given
--- no file arguments it reads the text from stdin and prints the
--- tidied text to stdout, which is exactly the shape the runner
--- wants: text in, prettier text out, nothing written to disk.

---@type FormatterSpec
return {
    cmd = 'docstrfmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'rst',
}
