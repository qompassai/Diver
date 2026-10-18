-- ~/.config/nvim/lua/formatters/typstyle.lua
-- typstyle formatter
---@module 'formatters.typstyle'

---@source https://github.com/Enter-tainer/typstyle

-- typstyle is an opinionated Typst formatter. With no input path it
-- reads the buffer from stdin and prints the formatted document to
-- stdout. `--column 100` matches the tiger-style line width instead
-- of the tool's narrower default.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { '--column', '100' },
    automatic = true,
    cmd = 'typstyle',
    cwd = nil,
    decode = nil,
    description = 'Opinionated Typst formatter; no path reads stdin, prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'typst' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
