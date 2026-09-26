-- #################################################################
-- ~/.config/nvim/lua/formatters/cabal_fmt.lua
-- Native cabal-fmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/phadej/cabal-fmt/blob/HEAD/README.md
---
--- cabal-fmt tidies Haskell package description files (the `.cabal` files
--- that list a project's modules and dependencies): it aligns fields into
--- neat tables and sorts lists the same way every time.
---
--- With no file arguments it reads the package description from stdin and
--- prints the tidied result to stdout. The README's editor-integration
--- section uses a bare `cabal-fmt` for exactly this buffer workflow; the
--- changelog confirms stdin is a supported input, and `--inplace` is only
--- for formatting files on disk.

---@type FormatterSpec
return {
    cmd = 'cabal-fmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    root_markers = {
        'cabal.project',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'cabal',
}
