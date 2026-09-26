-- #################################################################
-- ~/.config/nvim/lua/formatters/djlint.lua
-- Native djlint Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/djlint/djlint/blob/HEAD/docs/src/docs/getting-started.md
---
--- djlint tidies HTML templates (Django, Jinja, Nunjucks,
--- Handlebars). The `-` tells it "your template is coming through the
--- pipe, not from a file", and `--reformat` says "hand back only the
--- pretty code, no chatter". When the buffer was opened from a real
--- file we also pass its name with `--stdin-filename`, so djlint can
--- apply per-file rules exactly as if it had read the file itself.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local args = { '-', '--reformat' }
    if context.filename ~= '' then
        args[#args + 1] = '--stdin-filename'
        args[#args + 1] = context.filename
    end
    return args
end

---@type FormatterSpec
return {
    cmd = 'djlint',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'html',
}
