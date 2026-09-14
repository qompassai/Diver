-- #################################################################
-- ~/.config/nvim/lua/formatters/shfmt.lua
-- Qompass AI Diver shfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
-- No formatter plugin. The runner owns deadlines, cancellation, byte limits,
-- stale-result checks and atomic buffer updates. Neither tool writes source files.
-- CLI reference: mvdan.cc/sh/v3/cmd/shfmt (man 2025-06-22).
-- https://github.com/mvdan/sh
-- Zero operands selects stdin (do not append a filename or '-').
-- Parser/printer flags are all set, so EditorConfig indent/style is ignored.
-- That is intentional: style is this argv, not a hidden .editorconfig merge.
-- -i=0 is tabs. Not derived from Neovim shiftwidth/expandtab.
-- -ln=auto uses -filename, then shebang, then bash. .sh implies posix unless
-- a shebang overrides. -p=false so posix is not forced over auto.
-- -filename is the original path for dialect detection only; never a write target.
-- Empty -filename is explicit: unnamed buffers rely on shebang then bash.
-- --apply-ignore=false formats stdin even if EditorConfig would ignore the path.
-- An ignored file with that flag set prints nothing; allow_empty would reject it.
-- -s=false leaves optional simplify off. -mn=false leaves minify off (implies -s).
-- -l/-w/-d are off: no path lists, no in-place writes, no diff-as-output.
-- -f/--to-json/--from-json=false so stdout stays shell text, not paths or JSON.
-- -h/-help are omitted because they request help, even with '=false'.
-- -version=false does not print the version or exit.
-- -bn/-ci/-sr/-kp/-fn are the upstream defaults (all off), not Google's -i 2 -ci -bn.

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

---@param context FormatterContext
---@return string[]
local function args(context)
        return {
                '-version=false',
                '-l=false',
                '-w=false',
                '-d=false',
                '-s=false',
                '-mn=false',
                '--apply-ignore=false',
                '-ln=auto',
                '-p=false',
                '-filename=' .. context.filename,
                '-i=0',
                '-bn=false',
                '-ci=false',
                '-sr=false',
                '-kp=false',
                '-fn=false',
                '-f=false',
                '--to-json=false',
                '--from-json=false',
        }
end

---@type FormatterSpec
return {
        cmd = 'shfmt',
        args = args,
        mode = 'stdin',
        output = 'stdout',
        cwd = working_directory,
        root_markers = { '.editorconfig', '.git' },
        env = { NO_COLOR = '1', TERM = 'dumb' },
        exit_codes = { 0 },
        automatic = true,
        allow_empty = false,
        extension = 'sh',
}