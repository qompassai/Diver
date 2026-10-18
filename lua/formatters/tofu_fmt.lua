-- ~/.config/nvim/lua/formatters/tofu_fmt.lua
-- tofu fmt formatter
---@module 'formatters.tofu_fmt'

---@source https://opentofu.org/docs/cli/commands/fmt/

-- `tofu fmt` is OpenTofu's canonical configuration formatter. A
-- single dash as the target makes it read from stdin and print the
-- formatted configuration to stdout, mirroring terraform fmt.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'fmt', '-' },
    automatic = true,
    cmd = 'tofu',
    cwd = nil,
    decode = nil,
    description = 'OpenTofu canonical formatter; `fmt -` reads stdin, prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'terraform', 'terraform-vars' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
