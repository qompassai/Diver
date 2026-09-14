-- #################################################################
-- ~/.config/nvim/lua/formatters/bibtex_tidy.lua
-- Qompass AI Diver BibTeX Tidy Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
-- No formatter plugin. The runner owns deadlines, cancellation, byte limits,
-- stale-result checks and atomic buffer updates. This tool must not write
-- source files, backups, or --output paths.
-- CLI reference: FlamingTempura/bibtex-tidy v1.15.1 (Homebrew stable).
-- https://github.com/FlamingTempura/bibtex-tidy
-- Zero operands selects stdin (do not append a filename or '-').
-- v1 overwrites input files unless --no-modify is set. --v2 makes that the
-- documented contract; --no-modify is still passed so stdout is explicit.
-- --output/-o is omitted: a path writes a file. Stdout is the default when
-- --modify is off and --output is absent.
-- --help/-h and --version/-v are omitted because they request help/version
-- even with a false-looking value.
-- Positive-only rewrite flags are omitted (no documented --no-* invert):
--   --omit, --months, --duplicates, --strip-enclosing-braces, --drop-all-caps,
--   --generate-keys, --max-authors, --enclosing-braces, --remove-braces.
-- Passing them would delete fields, rewrite months/keys/authors, merge on
-- duplicate detection, or strip/add braces. An empty --omit= is not a keep-all.
-- --lowercase is not a documented flag; lowercase names/types are the default.
-- --no-lowercase is omitted so that default stays in effect.
-- --backup is not in the v1.15 CLI.
-- Indent and alignment are fixed here, not derived from shiftwidth/expandtab.
-- --space is ignored when --tab is set, so --no-tab is required for spaces.
-- --quiet keeps diagnostic logs off stdout so the buffer only receives BibTeX.
-- External Node environment (PATH, nvm/fnm prefixes, NODE_PATH) is inherited
-- so the same bibtex-tidy executable resolves as in a project shell.

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
        cmd = 'bibtex-tidy',
        args = {
                '--v2',
                '--no-modify',
                '--quiet',
                '--curly',
                '--numeric',
                '--space=2',
                '--no-tab',
                '--align=14',
                '--no-blank-lines',
                '--no-sort',
                '--no-merge',
                '--no-escape',
                '--sort-fields=title,shorttitle,author,year,month,day,journal,booktitle,location,on,publisher,address,series,volume,number,pages,doi,isbn,issn,url,urldate,copyright,category,note,metadata',
                '--no-strip-comments',
                '--no-trailing-commas',
                '--no-encode-urls',
                '--tidy-comments',
                '--no-remove-empty-fields',
                '--remove-dupe-fields',
                '--no-wrap',
        },
        mode = 'stdin',
        output = 'stdout',
        cwd = working_directory,
        root_markers = { '.latexmkrc', 'latexmkrc', 'Tectonic.toml', '.git' },
        env = { NO_COLOR = '1', NODE_NO_WARNINGS = '1' },
        exit_codes = { 0 },
        automatic = true,
        allow_empty = false,
        extension = 'bib',
}