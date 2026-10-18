-- ~/.config/nvim/lua/formatters/rescript_format.lua
-- Native rescript format Formatter — Neovim 0.13+ / LuaJIT
---@module 'formatters.rescript_format'
---@source https://github.com/rescript-lang/rescript/blob/HEAD/CHANGELOG.md
---
--- ReScript 12 (Rust CLI) spelling: `rescript format --stdin <extension>`.
--- The legacy pre-12 CLI used the single-dash `-stdin <extension>`; that
--- spelling is not supported here. The extension is derived from the
--- buffer's filename so interface files (.resi) keep their syntax.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'rescript' then
        error('rescript_format requires the rescript filetype')
    end

    local extension = context.filename:match('%.res[ci]?$') or '.res'

    return { 'format', '--stdin', extension }
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'rescript',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = nil,
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'rescript.json', 'bsconfig.json', '.git' },
}
