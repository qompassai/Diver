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
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'zprint',
    cwd = nil,
    decode = nil,
    description = 'Clojure formatter; no arguments means stdin in, formatted stdout out',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'clojure' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
