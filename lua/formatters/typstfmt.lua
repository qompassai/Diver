-- #################################################################
-- ~/.config/nvim/lua/formatters/typstfmt.lua
-- typstfmt formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/astrale-sharp/typstfmt/issues/125

-- typstfmt formats Typst documents. By default it expects a file
-- path, but `--output -` makes it read the buffer from stdin and
-- print the formatted document to stdout. Note several forks share
-- this name; the upstream astrale-sharp project (continued by the
-- myriad-dreamin fork) is the one with this CLI.
---@type FormatterSpec
return {
    cmd = 'typstfmt',
    args = { '--output', '-' },
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
    description = 'Typst formatter; `--output -` reads stdin and prints formatted stdout',
}
