-- #################################################################
-- ~/.config/nvim/lua/formatters/efmt.lua
-- Native efmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/sile/efmt/blob/HEAD/README.md
---
--- efmt tidies Erlang code. The lone `-` means "read the code from
--- stdin and print the pretty version to stdout". Upstream warns that
--- piping through `rebar3 efmt` mangles stdin, so the adapter calls
--- the `efmt` binary directly instead.

---@type FormatterSpec
return {
    cmd = 'efmt',
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
