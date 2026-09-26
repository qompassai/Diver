-- #################################################################
-- ~/.config/nvim/lua/formatters/dfmt.lua
-- Native dfmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/dlang-community/dfmt
---
--- dfmt is the tidier for the D programming language. Run it with no
--- arguments at all and it behaves like a funnel: messy D code pours
--- in through stdin, clean D code comes out of stdout. It is
--- opinionated, so there are no style knobs to turn here.

---@type FormatterSpec
return {
    cmd = 'dfmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'd',
}
