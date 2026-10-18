-- ~/.config/nvim/lua/formatters/verible_verilog_format.lua
-- verible-verilog-format formatter
---@module 'formatters.verible_verilog_format'

---@source https://github.com/chipsalliance/verible

-- verible-verilog-format is the Verible Verilog/SystemVerilog
-- formatter. A lone `-` makes it read the buffer from stdin and
-- print the formatted code to stdout. It also accepts useful
-- knobs such as `--column_limit`, `--indentation_spaces`, and
-- `--stdin_name` if tighter control is ever needed.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { '-' },
    automatic = true,
    cmd = 'verible-verilog-format',
    cwd = nil,
    decode = nil,
    description = 'Verible Verilog/SystemVerilog formatter; `-` reads stdin, prints stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'verilog', 'systemverilog' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
