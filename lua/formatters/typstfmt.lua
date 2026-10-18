-- ~/.config/nvim/lua/formatters/typstfmt.lua
-- typstfmt formatter
---@module 'formatters.typstfmt'

---@source https://github.com/astrale-sharp/typstfmt/issues/125

-- typstfmt formats Typst documents. By default it expects a file
-- path, but `--output -` makes it read the buffer from stdin and
-- print the formatted document to stdout. Note several forks share
-- this name; the upstream astrale-sharp project (continued by the
-- myriad-dreamin fork) is the one with this CLI.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { '--output', '-' },
    automatic = true,
    cmd = 'typstfmt',
    cwd = nil,
    decode = nil,
    description = 'Typst formatter; `--output -` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'typst' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
