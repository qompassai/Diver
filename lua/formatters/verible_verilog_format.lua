-- #################################################################
-- ~/.config/nvim/lua/formatters/verible_verilog_format.lua
-- verible-verilog-format formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/chipsalliance/verible

-- verible-verilog-format is the Verible Verilog/SystemVerilog
-- formatter. A lone `-` makes it read the buffer from stdin and
-- print the formatted code to stdout. It also accepts useful
-- knobs such as `--column_limit`, `--indentation_spaces`, and
-- `--stdin_name` if tighter control is ever needed.
---@type FormatterSpec
return {
    cmd = 'verible-verilog-format',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
    filetypes = { 'verilog', 'systemverilog' },
    description = 'Verible Verilog/SystemVerilog formatter; `-` reads stdin, prints stdout',
}
