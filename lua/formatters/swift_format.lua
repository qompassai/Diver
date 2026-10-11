-- #################################################################
-- ~/.config/nvim/lua/formatters/swift_format.lua
-- swift-format formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://swiftpackageregistry.com/swiftlang/swift-format

-- swift-format is Apple's Swift code formatter. With no input paths
-- it reads Swift source from stdin and writes the formatted result
-- to stdout, unless in-place mode is requested. `--assume-filename`
-- gives it a file name so it can look up the right configuration
-- for the buffer, the same way it would for a real file.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        return {
            '--assume-filename',
            context.filename ~= '' and context.filename or 'buffer.swift',
        }
    end,
    automatic = true,
    cmd = 'swift-format',
    cwd = nil,
    decode = nil,
    description = 'Apple Swift formatter; no paths means stdin in, formatted stdout out',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'swift' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
