-- ~/.config/nvim/lua/formatters/taplo.lua
-- taplo formatter
---@module 'formatters.taplo'

---@source https://github.com/tamasfe/taplo/issues/704

-- taplo is a TOML toolkit. `fmt -` reads the buffer from stdin and
-- writes the formatted TOML to stdout. `--stdin-filepath` (when we
-- know the file name) lets taplo match path-specific configuration
-- the same way it would for a real file on disk.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        local args = { 'fmt' }
        if context.filename ~= '' then
            args[#args + 1] = '--stdin-filepath'
            args[#args + 1] = context.filename
        end
        args[#args + 1] = '-'
        return args
    end,
    automatic = true,
    cmd = 'taplo',
    cwd = nil,
    decode = nil,
    description = 'TOML toolkit; `fmt -` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'toml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
