-- #################################################################
-- ~/.config/nvim/lua/formatters/templ_fmt.lua
-- templ fmt formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/a-h/templ/blob/HEAD/docs/docs/09-developer-tools/01-cli.md

-- templ ships its own formatter. `templ fmt` with no file arguments
-- reads the buffer from stdin and writes the formatted templ code
-- to stdout.
---@type FormatterSpec
return {
    cmd = 'templ',
    args = { 'fmt' },
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
    filetypes = { 'templ' },
    description = 'templ code formatter; bare `fmt` reads stdin and prints formatted stdout',
}
