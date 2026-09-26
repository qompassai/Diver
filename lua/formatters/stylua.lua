-- #################################################################
-- ~/.config/nvim/lua/formatters/stylua.lua
-- stylua formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/johnnymorganz/stylua

-- Stylua is the opinionated Lua code formatter. A lone `-` tells it
-- to read the buffer from stdin and print the formatted code to
-- stdout, which is exactly what the runner feeds it.
---@type FormatterSpec
return {
    cmd = 'stylua',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
    filetypes = { 'lua', 'luau' },
    description = 'Opinionated Lua code formatter; `-` reads stdin and prints formatted stdout',
}
