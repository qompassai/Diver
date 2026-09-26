-- #################################################################
-- ~/.config/nvim/lua/formatters/erlfmt.lua
-- Native erlfmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/WhatsApp/erlfmt/releases/tag/v0.3.0
---
--- erlfmt is WhatsApp's tidier for Erlang code. The lone `-` means
--- "read the code from stdin and print the pretty version to stdout",
--- so the buffer never has to touch the disk.

---@type FormatterSpec
return {
    cmd = 'erlfmt',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'erl',
}
