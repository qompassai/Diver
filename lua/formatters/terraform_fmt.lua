-- ~/.config/nvim/lua/formatters/terraform_fmt.lua
-- terraform fmt formatter
---@module 'formatters.terraform_fmt'

---@source https://developer.hashicorp.com/terraform/cli/v1.10.x/commands/fmt

-- `terraform fmt` rewrites Terraform configuration to the canonical
-- style. A single dash as the target makes it read from stdin and
-- print the formatted configuration to stdout; the no-write
-- behaviour is implied when the input is stdin.
---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'fmt', '-' },
    automatic = true,
    cmd = 'terraform',
    cwd = nil,
    decode = nil,
    description = 'Terraform canonical formatter; `fmt -` reads stdin, prints formatted stdout',
    env = {},
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'terraform', 'terraform-vars' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
