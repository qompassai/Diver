-- #################################################################
-- ~/.config/nvim/lua/formatters/yapf.lua
-- yapf formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/google/yapf

-- yapf is Google's Python formatter. When no files are named it
-- reads Python source from stdin and prints the formatted source
-- to stdout, so the adapter needs no extra arguments. (The linked
-- source is a mirror of google/yapf.)
---@type FormatterSpec
return {
    cmd = 'yapf',
    args = {},
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
    filetypes = { 'python' },
    description = 'Google Python formatter; no files means stdin in, formatted stdout out',
}
