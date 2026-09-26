-- #################################################################
-- ~/.config/nvim/lua/formatters/black.lua
-- Native Black Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/psf/black
---
--- Black is the "no arguments" code tidier for Python: it rewrites code in
--- one fixed style, so nobody argues about formatting ever again.
---
--- `-` means: "read the code I hand you through stdin and print the tidied
--- code back to stdout." `--quiet` keeps it silent when it succeeds, and
--- `--stdin-filename <path>` tells it which file the piped code pretends to
--- be, which helps it find the project's settings. The filename flag is
--- skipped for unnamed buffers.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local args = { '--quiet' }
    if context.filename ~= '' then
        args[#args + 1] = '--stdin-filename'
        args[#args + 1] = context.filename
    end
    args[#args + 1] = '-'
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
    cmd = 'black',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'pyproject.toml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'py',
}
