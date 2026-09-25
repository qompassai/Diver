-- #################################################################
-- ~/.config/nvim/lua/formatters/prettierd.lua
-- Qompass AI Diver Prettierd Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/fsouza/prettierd
---
--- prettierd is a persistent Prettier daemon: it keeps Prettier warm
--- so formatting is instant. It reads the source from stdin and
--- takes the filename as its first argument, which it uses for
--- parser inference and config lookup. Unnamed buffers are refused
--- because the daemon cannot infer a parser without a filename.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filename == '' then
        error('prettierd: needs a filename to infer the parser')
    end
    return { context.filename }
end

---@type FormatterSpec
return {
    cmd = 'prettierd',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'js',
}
