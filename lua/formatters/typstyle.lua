-- #################################################################
-- ~/.config/nvim/lua/formatters/typstyle.lua
-- typstyle formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/Enter-tainer/typstyle

-- typstyle is an opinionated Typst formatter. With no input path it
-- reads the buffer from stdin and prints the formatted document to
-- stdout. `--column 100` matches the tiger-style line width instead
-- of the tool's narrower default.
---@type FormatterSpec
return {
    cmd = 'typstyle',
    args = { '--column', '100' },
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
    filetypes = { 'typst' },
    description = 'Opinionated Typst formatter; no path reads stdin, prints formatted stdout',
}
