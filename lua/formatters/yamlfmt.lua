-- ~/.config/nvim/lua/formatters/yamlfmt.lua
-- yamlfmt formatter
---@module 'formatters.yamlfmt'

---@source https://github.com/google/yamlfmt/blob/HEAD/docs/command-usage.md

-- yamlfmt is Google's YAML formatter. A lone `-` makes it read the
-- buffer from stdin and print the formatted YAML to stdout, as
-- documented in its command-usage guide.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { '-' },
    automatic = true,
    cmd = 'yamlfmt',
    cwd = nil,
    decode = nil,
    description = 'Google YAML formatter; `-` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'yaml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
