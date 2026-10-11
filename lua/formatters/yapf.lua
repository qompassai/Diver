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
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'yapf',
    cwd = nil,
    decode = nil,
    description = 'Google Python formatter; no files means stdin in, formatted stdout out',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'python' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
