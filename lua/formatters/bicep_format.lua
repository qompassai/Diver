-- #################################################################
-- ~/.config/nvim/lua/formatters/bicep_format.lua
-- Native bicep format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/Azure/bicep

---
--- Tiger Style note for Bicep: `bicep format <file>` takes the file as a
--- positional argument and formats it in place; stdin is not supported, so
--- the runner uses a private tempfile. The tempfile keeps the buffer's
--- basename, preserving the .bicep extension. Bicep's style is opinionated
--- (2-space indentation is canonical); no verified CLI flags exist for
--- indent or width, so none are passed.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'bicep' then
        error('bicep_format requires the bicep filetype')
    end

    return { 'format', assert(context.tempfile) }
end

---@type FormatterSpec
return {
    cmd = 'bicep',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
}
