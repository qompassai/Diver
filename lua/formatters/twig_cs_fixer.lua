-- ~/.config/nvim/lua/formatters/twig_cs_fixer.lua
-- twig-cs-fixer formatter
---@module 'formatters.twig_cs_fixer'

---@source https://github.com/vincentlanglet/twig-cs-fixer/blob/HEAD/README.md

-- twig-cs-fixer has no stdin mode upstream (stdin support is still
-- an open feature request), so this adapter runs on a private
-- tempfile instead. `fix <path>` rewrites the file in place and the
-- runner reads the fixed file back as the new buffer text.
-- `--no-cache` keeps repeated runs deterministic.
---@type FormatterSpec
return {
    allow_empty = false,
    args = function(context)
        return {
            'fix',
            '--no-cache',
            assert(context.tempfile),
        }
    end,
    automatic = true,
    cmd = 'twig-cs-fixer',
    cwd = nil,
    decode = nil,
    description = 'Twig fixer; rewrites a private tempfile in place, runner reads it back',
    env = {},
    exit_codes = { 0 },
    extension = 'twig',
    filetypes = { 'twig' },
    mode = 'tempfile',
    output = 'file',
    pre_transform = nil,
    root_markers = {},
}
