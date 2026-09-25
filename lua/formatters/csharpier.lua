-- #################################################################
-- ~/.config/nvim/lua/formatters/csharpier.lua
-- Native CSharpier Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://csharpier.com/docs/CLI
---
--- CSharpier is the code tidier for C#: it rewrites C# code with clean,
--- consistent style, the same way for everyone.
---
--- `format` is the formatting subcommand. With no file argument it reads code
--- from stdin and prints the tidied code to stdout. `--stdin-path <path>`
--- tells it which file the piped code pretends to be, so it can find the
--- project's settings; the flag is skipped for unnamed buffers.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local args = { 'format' }
    if context.filename ~= '' then
        args[#args + 1] = '--stdin-path'
        args[#args + 1] = context.filename
    end
    return args
end

---@param context FormatterContext
---@return string
local function working_directory(context)
    if context.filename ~= '' then
        local directory = vim.fs.dirname(context.filename)
        if directory then
            return directory
        end
    end
    return context.root
end

---@type FormatterSpec
return {
    cmd = 'csharpier',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.csharpierrc',
        '.csharpierrc.json',
        '.csharpierrc.yaml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'cs',
}
