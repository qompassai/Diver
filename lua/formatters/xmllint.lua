-- #################################################################
-- ~/.config/nvim/lua/formatters/xmllint.lua
-- xmllint formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://manpages.debian.org/unstable/libxml2-utils/xmllint.1.en.html

-- xmllint ships with libxml2 and doubles as an XML reformatter.
-- `--format -` makes it reformat and reindent the document it
-- reads from stdin, printing the result to stdout. The
-- XMLLINT_INDENT environment variable controls indentation, so it
-- is set to four spaces to match tiger style (the tool default is
-- two spaces).
---@type FormatterSpec
return {
    cmd = 'xmllint',
    args = { '--format', '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = { XMLLINT_INDENT = '    ' },
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
    filetypes = { 'xml' },
    description = 'libxml2 XML reformatter; `--format -` reads stdin, prints formatted stdout',
}
