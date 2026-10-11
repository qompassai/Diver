-- #################################################################
-- ~/.config/nvim/lua/formatters/zig_fmt.lua
-- Native zig fmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://ziglang.org/documentation/master/#zig-fmt

---
--- Tiger Style note for Zig: `zig fmt --stdin` reads stdin and writes the
--- formatted source to stdout. The built-in formatter is opinionated
--- (4-space layout, ~100 columns per Tiger Style Zig); no width or
--- indentation flags exist, so none are passed.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'zig' then
        error('zig_fmt requires the zig filetype')
    end

    return { 'fmt', '--stdin' }
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'zig',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = nil,
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'build.zig', 'build.zig.zon', '.git' },
}
