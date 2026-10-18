-- ~/.config/nvim/lua/formatters/templ_fmt.lua
-- templ fmt formatter
---@module 'formatters.templ_fmt'

---@source https://github.com/a-h/templ/blob/HEAD/docs/docs/09-developer-tools/01-cli.md

-- templ ships its own formatter. `templ fmt` with no file arguments
-- reads the buffer from stdin and writes the formatted templ code
-- to stdout.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'fmt' },
    automatic = true,
    cmd = 'templ',
    cwd = nil,
    decode = nil,
    description = 'templ code formatter; bare `fmt` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'templ' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
