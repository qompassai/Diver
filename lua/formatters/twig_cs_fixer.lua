-- #################################################################
-- ~/.config/nvim/lua/formatters/twig_cs_fixer.lua
-- twig-cs-fixer formatter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

---@source https://github.com/vincentlanglet/twig-cs-fixer/blob/HEAD/README.md

-- twig-cs-fixer has no stdin mode upstream (stdin support is still
-- an open feature request), so this adapter runs on a private
-- tempfile instead. `fix <path>` rewrites the file in place and the
-- runner reads the fixed file back as the new buffer text.
-- `--no-cache` keeps repeated runs deterministic.
---@type FormatterSpec
return {
    cmd = 'twig-cs-fixer',
    args = function(context)
        return {
            'fix',
            '--no-cache',
            assert(context.tempfile),
        }
    end,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'twig',
    decode = nil,
    pre_transform = nil,
    filetypes = { 'twig' },
    description = 'Twig fixer; rewrites a private tempfile in place, runner reads it back',
}
