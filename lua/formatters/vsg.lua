-- ~/.config/nvim/lua/formatters/vsg.lua
-- vsg formatter
---@module 'formatters.vsg'

---@source https://github.com/jeremiah-c-leary/vhdl-style-guide/issues/1409

-- vsg (VHDL Style Guide) checks and fixes VHDL style. It works on
-- files, not stdin, so this adapter runs on a private tempfile:
-- `--fix -f <path>` rewrites the file in place and the runner reads
-- the fixed file back as the new buffer text. vsg reports a
-- non-zero exit code when rules were violated (even fixable ones),
-- so both 0 and 1 are accepted; anything else is a real error.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        return {
            '--fix',
            '-f',
            assert(context.tempfile),
        }
    end,
    automatic = true,
    cmd = 'vsg',
    cwd = nil,
    decode = nil,
    description = 'VHDL style fixer; `--fix -f` rewrites a private tempfile in place',
    env = {},
    exit_codes = { 0, 1 },
    extension = 'vhd',
    filetypes = { 'vhdl' },
    mode = 'tempfile',
    output = 'file',
    pre_transform = nil,
    root_markers = {},
}
