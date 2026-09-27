-- tests/lua/lang_coverage_adversarial.lua
-- Adversarial suite for the language tooling coverage manifest generator:
-- exactly half of the 24-check lang_coverage program (12 checks here,
-- 12 in lang_coverage_validation.lua).
--
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/lang_coverage_adversarial.lua
--
-- Exit 0 when every check behaves, 1 otherwise. The record goes to
-- $LANG_COV_ADV_REPORT (default /tmp/lang_coverage_adversarial_report.txt);
-- print() is unreliable under this headless invocation, so the file is the
-- record.
local report_path = os.getenv('LANG_COV_ADV_REPORT') or '/tmp/lang_coverage_adversarial_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end

local adv_passed, adv_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end

local gen = require('config.lang.coverage_gen')

---@return LangCoverageRaw small synthetic registry data (fixture, not the real registries)
local function fixture_raw()
    return {
        formatters = {
            fa = { 'fmt_a' },
            fb = { 'fmt_b1', 'fmt_b2' },
        },
        linters = {
            fa = { 'lint_a' },
            fc = { 'lint_c' },
        },
        lsp = {
            fa = { 'a_ls' },
            fb = { 'b_ls' },
        },
        lsp_skipped = {},
        dap = {
            fc = { 'dap_c' },
        },
        bsp = { fb = true },
        browser = {},
    }
end

-- A1-A2: a manifest that drops a filetype the registries know must fail
-- loudly (mutated fixture registry), naming the missing filetype.
do
    local raw = fixture_raw()
    local manifest = gen.build(raw)
    raw.linters.zz_new = { 'lint_zz' }
    local ok, missing = gen.verify(manifest, raw)
    adv_check(ok == false, 'verify fails when a registry filetype is missing from the manifest')
    adv_check(
        type(missing) == 'table' and #missing == 1 and missing[1]:find('zz_new', 1, true) ~= nil,
        'verify names the missing filetype and its source'
    )
end

-- A3-A5: duplicate entries collapse -- one filetype key, deduplicated lists.
do
    local raw = fixture_raw()
    raw.formatters.dupft = { 'fmt_x', 'fmt_x', { 'fmt_y', 'fmt_y' } }
    raw.lsp.dupft = { 'd_ls' }
    raw.dap.dupft = { 'dap_d', 'dap_d' }
    local manifest = gen.build(raw)
    adv_check(#manifest.dupft.formatters == 2, 'duplicate formatter names deduplicated to 2')
    adv_check(#manifest.dupft.dap == 1, 'duplicate dap modules deduplicated to 1')
    local key_count = 0
    for ft in pairs(manifest) do
        if ft == 'dupft' then
            key_count = key_count + 1
        end
    end
    adv_check(key_count == 1, 'duplicate filetype collapses to a single manifest entry')
end

-- A6-A9: determinism -- emit twice and regenerate twice are byte-identical.
do
    local text1 = gen.emit(gen.build(fixture_raw()), {
        filetypes = 0,
        bytes = 0,
        path = 'fixture',
        lsp_files = 0,
        lsp_loaded = 0,
        lsp_skipped = 0,
        dap_entries = 0,
    })
    local text2 = gen.emit(gen.build(fixture_raw()), {
        filetypes = 0,
        bytes = 0,
        path = 'fixture',
        lsp_files = 0,
        lsp_loaded = 0,
        lsp_skipped = 0,
        dap_entries = 0,
    })
    adv_check(text1 == text2, 'emit twice from fixtures is byte-identical')

    local p1, p2 = vim.fn.tempname(), vim.fn.tempname()
    local s1, e1 = gen.regenerate(p1)
    local s2, e2 = gen.regenerate(p2)
    adv_check(s1 ~= nil and s2 ~= nil, 'regenerate to temp paths succeeds (' .. tostring(e1 or e2) .. ')')
    if s1 ~= nil and s2 ~= nil then
        adv_check(s1.filetypes == s2.filetypes and s1.filetypes > 400, 'regenerate reports the same filetype count')
        local b1 = table.concat(vim.fn.readfile(p1), '\n')
        local b2 = table.concat(vim.fn.readfile(p2), '\n')
        adv_check(b1 == b2 and #b1 > 0, 'regenerate twice is byte-identical output')
    else
        adv_check(false, 'regenerate reports the same filetype count (skipped: regenerate failed)')
        adv_check(false, 'regenerate twice is byte-identical output (skipped: regenerate failed)')
    end
    os.remove(p1)
    os.remove(p2)
end

-- A10-A12: stub-deletion guard -- deleting a stub that is still required
-- must fail loudly; the purged stubs must have zero remaining references.
---@param name string lang module short name, e.g. 'julia'
---@return string[] files referencing config.lang.<name>
local function references_lang_module(name)
    local root = vim.fn.getcwd()
    ---@type string[]
    local hits = {}
    for _, line in ipairs(vim.fn.readfile(root .. '/lua/config/lang/init.lua')) do
        if line:find("'" .. name .. "'", 1, true) ~= nil then
            hits[#hits + 1] = 'lua/config/lang/init.lua'
            break
        end
    end
    local files = vim.fn.globpath(root .. '/lua', '**/*.lua', false, true)
    local pattern = 'config%.lang%.' .. name .. '["\']'
    for _, path in ipairs(files) do
        if path:find('/lua/config/lang/', 1, true) == nil then
            for _, line in ipairs(vim.fn.readfile(path)) do
                if line:find(pattern) ~= nil then
                    hits[#hits + 1] = path:sub(#root + 2)
                    break
                end
            end
        end
    end
    return hits
end

do
    -- 'lua' is still required (lua/utils/ddx.lua); the guard must catch it.
    local ok_loud, _ = pcall(function()
        local hits = references_lang_module('lua')
        assert(#hits > 0, 'guard blind to a live require')
        error('stub still required by: ' .. table.concat(hits, ', '))
    end)
    adv_check(not ok_loud, 'deleting a still-required stub fails loudly')
    adv_check(#references_lang_module('julia') == 0, 'purged stub julia has no remaining references')
    adv_check(#references_lang_module('ada') == 0, 'purged stub ada has no remaining references')
end

emit(string.format('RESULT: %d passed, %d failed', adv_passed, adv_failed))
local fh = assert(io.open(report_path, 'w'))
fh:write(table.concat(log_lines, '\n') .. '\n')
fh:close()
if adv_failed > 0 then
    vim.cmd('cquit 1')
end
vim.cmd('quit')
