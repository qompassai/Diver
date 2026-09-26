-- #################################################################
-- ~/.config/nvim/lua/formatters/bibtex_tidy.lua
-- Native bibtex-tidy Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/flamingtempura/bibtex-tidy/blob/HEAD/README.md
---
--- bibtex-tidy tidies BibTeX reference files: it lines up the `=` signs,
--- lowercases entry types and field names, and makes every entry look the
--- same. The npm package ships a `bibtex-tidy` command-line tool.
---
--- The CLI reads BibTeX from stdin when no input file is given and prints
--- the tidied result to stdout. `--no-modify` guards against its default
--- in-place behavior and `--quiet` keeps log chatter off stdout, so only
--- the tidied BibTeX comes back. A file argument is deliberately not
--- passed: when stdin is not a TTY the CLI silently ignores trailing file
--- arguments and tidies empty stdin instead.

---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@type FormatterSpec
return {
    cmd = 'bibtex-tidy',
    args = { '--no-modify', '--quiet' },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.latexmkrc',
        'latexmkrc',
        'tectonic.toml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
}
