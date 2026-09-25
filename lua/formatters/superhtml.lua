-- #################################################################
-- ~/.config/nvim/lua/formatters/superhtml.lua
-- superhtml formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/kristoff-it/superhtml/blob/HEAD/README.md

-- superhtml formats HTML documents. `fmt --stdin` makes it read the
-- buffer from stdin and write the formatted document to stdout.
---@type FormatterSpec
return {
    cmd = 'superhtml',
    args = { 'fmt', '--stdin' },
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
    filetypes = { 'html', 'superhtml' },
    description = 'HTML formatter; `fmt --stdin` reads stdin and prints formatted stdout',
}
