-- #################################################################
-- ~/.config/nvim/lua/formatters/autopep8.lua
-- Native autopep8 Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/hhatto/autopep8/blob/main/README.rst
---
--- autopep8 is a code tidier for Python: it fixes the little style mistakes
--- (extra spaces, missing blank lines, bad indentation) so the code follows
--- the rules most Python projects agree on.
---
--- A lone `-` as the input file means: "read the code I hand you through
--- stdin and print the tidied code back to stdout." The README documents
--- `autopep8 -` for exactly this pipe workflow. We run it from the file's
--- own directory so it finds the project's setup.cfg / tox.ini /
--- .pycodestyle settings.

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
    cmd = 'autopep8',
    args = {
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'setup.cfg',
        'tox.ini',
        '.pycodestyle',
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
