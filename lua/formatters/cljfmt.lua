-- #################################################################
-- ~/.config/nvim/lua/formatters/cljfmt.lua
-- Native cljfmt Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/weavejester/cljfmt/blob/HEAD/README.md
---
--- cljfmt is a code tidier for Clojure: it rewrites Clojure code with clean,
--- consistent indentation and spacing.
---
--- `fix` is the subcommand that rewrites code (instead of just checking it),
--- and `-` as the path means: "read from stdin and print the tidied code to
--- stdout." The README documents exactly this: "If the path is `-`, then the
--- input is STDIN, and the output STDOUT."

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
    cmd = 'cljfmt',
    args = {
        'fix',
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.cljfmt.edn',
        'deps.edn',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'clj',
}
