-- ~/.config/nvim/lua/formatters/stylua.lua
-- stylua formatter
---@module 'formatters.stylua'

---@source https://github.com/johnnymorganz/stylua

-- Stylua is the opinionated Lua code formatter. A lone `-` tells it
-- to read the buffer from stdin and print the formatted code to
-- stdout, which is exactly what the runner feeds it.
--
-- The single source of truth for StyLua options is lsp/stylua_ls.lua
-- (this config carries no .stylua.toml / stylua.toml files). The args
-- below mirror those settings as explicit CLI flags: with no config
-- file to discover, a bare `stylua -` would fall back to StyLua
-- defaults (tabs, double quotes) and silently reformat wrong.
---@type FormatterSpec
return {
    allow_empty = false,
    args = {
        '--call-parentheses',
        'Always',
        '--collapse-simple-statement',
        'Never',
        '--column-width',
        '120',
        '--indent-type',
        'Spaces',
        '--indent-width',
        '4',
        '--line-endings',
        'Unix',
        '--preserve-block-newline-gaps',
        'Never',
        '--quote-style',
        'AutoPreferSingle',
        '--sort-requires',
        '--space-after-function-names',
        'Never',
        '--syntax',
        'All',
        '-',
    },
    automatic = true,
    cmd = 'stylua',
    cwd = nil,
    decode = nil,
    description = 'Opinionated Lua code formatter; `-` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'lua', 'luau' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
