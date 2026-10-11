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
    allow_empty = false,
    args = { '--format', '-' },
    automatic = true,
    cmd = 'xmllint',
    cwd = nil,
    decode = nil,
    description = 'libxml2 XML reformatter; `--format -` reads stdin, prints formatted stdout',
    env = { XMLLINT_INDENT = '    ' },
    exit_codes = { 0 },
    extension = nil,
    filetypes = { 'xml' },
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {},
}
