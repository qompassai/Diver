-- #################################################################
-- ~/.config/nvim/lua/formatters/taplo.lua
-- taplo formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/tamasfe/taplo/issues/704

-- taplo is a TOML toolkit. `fmt -` reads the buffer from stdin and
-- writes the formatted TOML to stdout. `--stdin-filepath` (when we
-- know the file name) lets taplo match path-specific configuration
-- the same way it would for a real file on disk.
---@type FormatterSpec
return {
    cmd = 'taplo',
    args = function(context)
        local args = { 'fmt' }
        if context.filename ~= '' then
            args[#args + 1] = '--stdin-filepath'
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
    description = 'TOML toolkit; `fmt -` reads stdin and prints formatted stdout',
}
