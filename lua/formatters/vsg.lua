-- #################################################################
-- ~/.config/nvim/lua/formatters/vsg.lua
-- vsg formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/jeremiah-c-leary/vhdl-style-guide/issues/1409

-- vsg (VHDL Style Guide) checks and fixes VHDL style. It works on
-- files, not stdin, so this adapter runs on a private tempfile:
-- `--fix -f <path>` rewrites the file in place and the runner reads
-- the fixed file back as the new buffer text. vsg reports a
-- non-zero exit code when rules were violated (even fixable ones),
-- so both 0 and 1 are accepted; anything else is a real error.
---@type FormatterSpec
return {
    cmd = 'vsg',
    args = function(context)
        return {
            '--fix',
            '-f',
            assert(context.tempfile),
        }
    end,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0, 1 },
    allow_empty = false,
    automatic = true,
    extension = 'vhd',
    decode = nil,
    pre_transform = nil,
    filetypes = { 'vhdl' },
    description = 'VHDL style fixer; `--fix -f` rewrites a private tempfile in place',
}
