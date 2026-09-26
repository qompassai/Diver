-- #################################################################
-- ~/.config/nvim/lua/formatters/yamlfmt.lua
-- yamlfmt formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/google/yamlfmt/blob/HEAD/docs/command-usage.md

-- yamlfmt is Google's YAML formatter. A lone `-` makes it read the
-- buffer from stdin and print the formatted YAML to stdout, as
-- documented in its command-usage guide.
---@type FormatterSpec
return {
    cmd = 'yamlfmt',
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
    filetypes = { 'yaml' },
    description = 'Google YAML formatter; `-` reads stdin and prints formatted stdout',
}
