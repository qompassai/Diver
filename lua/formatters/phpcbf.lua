-- #################################################################
-- ~/.config/nvim/lua/formatters/phpcbf.lua
-- Qompass AI Diver Phpcbf Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/PHPCSStandards/PHP_CodeSniffer/wiki/Fixing-Errors-Automatically
---
--- phpcbf is the auto-fixer shipped with PHP_CodeSniffer. The `-`
--- argument makes it read PHP source from stdin; `--stdin-path`
--- tells it which filename the text should be treated as, so the
--- right tokenizer and ruleset apply. Unnamed buffers fall back to
--- `stdin.php` because only PHP is ever formatted here.
---
--- Exit codes differ between major versions, so only the codes that
--- always mean "the printed text is the fixed result" are accepted:
--- 0 (nothing to fix, or fixed cleanly in v4) and 1 (v3: everything
--- fixable was fixed; v4: fixable issues remain but the output is
--- still the fixed text). Fix failures, processing errors and
--- unmet requirements (2, 3, 4, 16, 64 and their combinations)
--- are rejected so the buffer is left alone.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local stdin_path = context.filename ~= '' and context.filename or 'stdin.php'
    return { '--stdin-path=' .. stdin_path, '-' }
end

---@type FormatterSpec
return {
    cmd = 'phpcbf',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0, 1 },
    automatic = true,
    allow_empty = false,
    extension = 'php',
}
