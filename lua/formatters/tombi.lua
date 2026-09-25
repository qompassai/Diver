-- #################################################################
-- ~/.config/nvim/lua/formatters/tombi.lua
-- tombi formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/tombi-toml/tombi/pull/451

-- tombi is a TOML toolkit and formatter. `tombi format` with a `-`
-- path reads the buffer from stdin; since v0.4.0 it always prints
-- the formatted TOML to stdout, even when nothing changed. Older
-- tombi releases printed nothing for already-clean input, so keep
-- the binary reasonably current. `--stdin-filename` (when we know
-- the file name) lets tombi match path-specific configuration.
---@type FormatterSpec
return {
    cmd = 'tombi',
    args = function(context)
        local args = { 'format' }
        if context.filename ~= '' then
            args[#args + 1] = '--stdin-filename'
            args[#args + 1] = context.filename
        end
        args[#args + 1] = '-'
        return args
    end,
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
    filetypes = { 'toml' },
    description = 'TOML formatter; `format -` reads stdin and prints formatted stdout',
}
