-- #################################################################
-- ~/.config/nvim/lua/formatters/crystal_format.lua
-- Native crystal tool format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://crystal-lang.org/reference/1.12/man/crystal/

---
--- Tiger Style note for Crystal: `crystal tool format -` reads stdin and
--- emits the formatted source on stdout (the positional `-` selects stdin).
--- `--no-color` keeps diagnostics plain for the runner to capture. The
--- formatter is opinionated; no width or indentation flags exist, so the
--- canonical Crystal style is kept as-is.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'crystal' then
        error('crystal_format requires the crystal filetype')
    end

    return { 'tool', 'format', '--no-color', '-' }
end

---@type FormatterSpec
return {
    cmd = 'crystal',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'shard.yml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
}
