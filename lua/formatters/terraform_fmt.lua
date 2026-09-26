-- #################################################################
-- ~/.config/nvim/lua/formatters/terraform_fmt.lua
-- terraform fmt formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://developer.hashicorp.com/terraform/cli/v1.10.x/commands/fmt

-- `terraform fmt` rewrites Terraform configuration to the canonical
-- style. A single dash as the target makes it read from stdin and
-- print the formatted configuration to stdout; the no-write
-- behaviour is implied when the input is stdin.
---@type FormatterSpec
return {
    cmd = 'terraform',
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
    description = 'Terraform canonical formatter; `fmt -` reads stdin, prints formatted stdout',
}
