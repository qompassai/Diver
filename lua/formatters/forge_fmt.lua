-- #################################################################
-- ~/.config/nvim/lua/formatters/forge_fmt.lua
-- Native forge fmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/foundry-rs/book/blob/HEAD/src/pages/forge/formatting.mdx
---@source https://github.com/foundry-rs/foundry/pull/1336
---
--- `forge fmt` is the Solidity tidier inside Foundry's `forge`
--- toolkit. The `-` means "read the contract from stdin instead of a
--- file", and `--raw` says "print just the pretty code, not a diff".
--- Together they turn the pipe into a one-shot formatter: Solidity
--- in, pretty Solidity out.

---@type FormatterSpec
return {
    cmd = 'forge',
    args = { 'fmt', '--raw', '-' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'foundry.toml', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'sol',
}
