-- ~/.config/nvim/lua/formatters/superhtml.lua
-- superhtml formatter
---@module 'formatters.superhtml'

---@source https://github.com/kristoff-it/superhtml/blob/HEAD/README.md

-- superhtml formats HTML documents. `fmt --stdin` makes it read the
-- buffer from stdin and write the formatted document to stdout.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'fmt', '--stdin' },
    automatic = true,
    cmd = 'superhtml',
    cwd = nil,
    decode = nil,
    description = 'HTML formatter; `fmt --stdin` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'html', 'superhtml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
