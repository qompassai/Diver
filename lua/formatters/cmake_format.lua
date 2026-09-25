-- #################################################################
-- ~/.config/nvim/lua/formatters/cmake_format.lua
-- Native cmake-format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/cheshirekow/cmake_format
---
--- cmake-format tidies CMake files (CMakeLists.txt and .cmake files): it
--- fixes indentation and wrapping so build scripts look the same everywhere.
---
--- `-` as the input file means: "read from stdin and print the tidied result
--- to stdout" (stdin support since v0.3.6; the null-ls builtin documents
--- `args = { "-" }` for this workflow). Reading from stdin also lets it
--- discover the project's `.cmake-format` settings, which is why we run it
--- from the file's own directory.

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
    cmd = 'cmake-format',
    args = {
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.cmake-format.py',
        '.cmake-format',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'cmake',
}
