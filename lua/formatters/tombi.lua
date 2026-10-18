-- ~/.config/nvim/lua/formatters/tombi.lua
-- tombi formatter
---@module 'formatters.tombi'

---@source https://github.com/tombi-toml/tombi/pull/451

-- tombi is a TOML toolkit and formatter. `tombi format` with a `-`
-- path reads the buffer from stdin; since v0.4.0 it always prints
-- the formatted TOML to stdout, even when nothing changed. Older
-- tombi releases printed nothing for already-clean input, so keep
-- the binary reasonably current. `--stdin-filename` (when we know
-- the file name) lets tombi match path-specific configuration.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        local args = { 'format' }
        if context.filename ~= '' then
            args[#args + 1] = '--stdin-filename'
            args[#args + 1] = context.filename
        end
        args[#args + 1] = '-'
        return args
    end,
    automatic = true,
    cmd = 'tombi',
    cwd = nil,
    decode = nil,
    description = 'TOML formatter; `format -` reads stdin and prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'toml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
