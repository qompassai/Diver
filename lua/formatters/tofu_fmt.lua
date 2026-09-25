-- #################################################################
-- ~/.config/nvim/lua/formatters/tofu_fmt.lua
-- tofu fmt formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://opentofu.org/docs/cli/commands/fmt/

-- `tofu fmt` is OpenTofu's canonical configuration formatter. A
-- single dash as the target makes it read from stdin and print the
-- formatted configuration to stdout, mirroring terraform fmt.
---@type FormatterSpec
return {
    cmd = 'tofu',
    args = { 'fmt', '-' },
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
    filetypes = { 'terraform', 'terraform-vars' },
    description = 'OpenTofu canonical formatter; `fmt -` reads stdin, prints formatted stdout',
}
