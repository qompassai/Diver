-- #################################################################
-- ~/.config/nvim/lua/formatters/xmlformat.lua
-- xmlformat formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/pamoller/xmlformatter/blob/HEAD/README.rst

-- xmlformat pretty-prints XML. A lone `-` makes it read the buffer
-- from stdin and print the formatted XML to stdout.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { '-' },
    automatic = true,
    cmd = 'xmlformat',
    cwd = nil,
    decode = nil,
    description = 'XML pretty-printer; `-` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'xml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
