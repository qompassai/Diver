-- #################################################################
-- ~/.config/nvim/lua/formatters/cookstyle.lua
-- Native Cookstyle Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/chef/cookstyle
---
--- Cookstyle is the code tidier and style police for Chef cookbooks (Ruby
--- code that configures servers). It is built on RuboCop, so it accepts
--- RuboCop's command-line flags. Mirrors the inline cookstyle registration
--- in init.lua.
---
--- `--autocorrect` tells it to fix the style mistakes it can fix safely.
--- `--stdin <path>` means: "read the code I hand you through stdin and print
--- the corrected code back to stdout, but pretend the code lives at <path> so
--- the right project settings and exclusions apply." `--force-exclusion`
--- honors the project's ignore list, while `--no-color` and `--stderr` keep
--- the machine-readable output clean. It exits 1 when it found (and fixed)
--- offenses, so both 0 and 1 mean success here. An unnamed buffer has no
--- path, so we refuse it loudly instead of guessing.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    assert(context.filename ~= '', 'Cookstyle requires a filename for configuration/exclusions')
    return {
        '--autocorrect',
        '--force-exclusion',
        '--no-color',
        '--stderr',
        '--format',
        'progress',
        '--stdin',
        context.filename,
    }
end

---@type FormatterSpec
return {
    cmd = 'cookstyle',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    root_markers = {
        '.rubocop.yml',
        'Gemfile',
        '.git',
    },
    exit_codes = { 0, 1 },
    automatic = true,
    allow_empty = false,
    extension = 'rb',
}
