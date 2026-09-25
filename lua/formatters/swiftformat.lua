-- #################################################################
-- ~/.config/nvim/lua/formatters/swiftformat.lua
-- SwiftFormat formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/nicklockwood/swiftformat/blob/HEAD/README.md

-- SwiftFormat (Nick Lockwood) formats Swift. The positional `stdin`
-- target reads Swift source from stdin and prints the formatted
-- result to stdout. `--stdinpath` hands it the buffer's file name
-- so it can find the right `.swiftformat` configuration file.
---@type FormatterSpec
return {
    cmd = 'swiftformat',
    args = function(context)
        return {
            'stdin',
            '--stdinpath',
            context.filename ~= '' and context.filename or 'buffer.swift',
        }
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
    filetypes = { 'swift' },
    description = 'Nick Lockwood Swift formatter; `stdin --stdinpath` reads stdin, prints stdout',
}
