-- ~/.config/nvim/lua/formatters/swiftformat.lua
-- SwiftFormat formatter
---@module 'formatters.swiftformat'

---@source https://github.com/nicklockwood/swiftformat/blob/HEAD/README.md

-- SwiftFormat (Nick Lockwood) formats Swift. The positional `stdin`
-- target reads Swift source from stdin and prints the formatted
-- result to stdout. `--stdinpath` hands it the buffer's file name
-- so it can find the right `.swiftformat` configuration file.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        return {
            'stdin',
            '--stdinpath',
            context.filename ~= '' and context.filename or 'buffer.swift',
        }
    end,
    automatic = true,
    cmd = 'swiftformat',
    cwd = nil,
    decode = nil,
    description = 'Nick Lockwood Swift formatter; `stdin --stdinpath` reads stdin, prints stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'swift' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
