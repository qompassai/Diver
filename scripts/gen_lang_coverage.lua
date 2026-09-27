-- scripts/gen_lang_coverage.lua
-- Re-runnable entry point for the language tooling coverage manifest.
--
-- Regenerates lua/config/lang/coverage.lua from the live registries
-- (formatters, linters, lsp/*_ls.lua, lua/dap, lua/bsp, dev/browser).
-- Deterministic: unchanged inputs produce a byte-identical file.
--
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l scripts/gen_lang_coverage.lua
--
-- Exit 0 when the manifest is written, 1 otherwise. The human-readable
-- record goes to $LANG_COVERAGE_REPORT (default /tmp/lang_coverage_report.txt);
-- print() is unreliable under this headless invocation.
local report_path = os.getenv('LANG_COVERAGE_REPORT') or '/tmp/lang_coverage_report.txt'

local gen = require('config.lang.coverage_gen')
local ok, stats = pcall(gen.regenerate)

local fh = assert(io.open(report_path, 'w'))
if ok and stats then
    fh:write(('ok: %d filetypes, %d bytes -> %s\n'):format(stats.filetypes, stats.bytes, stats.path))
    fh:write(
        ('lsp: %d files seen, %d loaded, %d skipped\n'):format(stats.lsp_files, stats.lsp_loaded, stats.lsp_skipped)
    )
    fh:write(('dap: %d MODULES entries parsed\n'):format(stats.dap_entries))
else
    fh:write('FAILED: ' .. tostring(stats) .. '\n')
end
fh:close()

if not ok then
    vim.cmd('cquit 1')
end
vim.cmd('quit')
