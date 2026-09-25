-- #################################################################
-- ~/.config/nvim/lua/formatters/dprint.lua
-- Native dprint Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/dprint/dprint/blob/HEAD/website/src/cli.md
---
--- dprint is a fast, pluggable code tidier. `fmt` starts a formatting
--- run, `--stdin` says "the code is coming through the pipe", and the
--- last argument is a file name (or extension) so dprint knows which
--- language plugin should handle the text. We pass the buffer's real
--- file name when it has one, and fall back to a plain `Dockerfile`
--- name for unnamed buffers.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local name = context.filename ~= '' and context.filename or 'Dockerfile'
    return { 'fmt', '--stdin', name }
end

---@type FormatterSpec
return {
    cmd = 'dprint',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'dprint.json', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'dockerfile',
}
