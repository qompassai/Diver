-- #################################################################
-- ~/.config/nvim/lua/formatters/zprint.lua
-- zprint formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/kkinnear/zprint/blob/HEAD/doc/using/files.md

-- zprint formats Clojure source. With no arguments it reads
-- Clojure source from stdin and writes the formatted source to
-- stdout, which is exactly what the runner feeds it.
---@type FormatterSpec
return {
    cmd = 'zprint',
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
    filetypes = { 'clojure' },
    description = 'Clojure formatter; no arguments means stdin in, formatted stdout out',
}
