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
    cmd = 'xmlformat',
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
    filetypes = { 'xml' },
    description = 'XML pretty-printer; `-` reads stdin and prints formatted stdout',
}
