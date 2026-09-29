-- tests/lua/lang_coverage_validation.lua
-- Validation suite for the language tooling coverage manifest: the second
-- half of the 24-check lang_coverage program (12 checks here, 12 adversarial
-- in lang_coverage_adversarial.lua).
--
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/lang_coverage_validation.lua
--
-- Exit 0 when every check behaves, 1 otherwise. The record goes to
-- $LANG_COV_VAL_REPORT (default /tmp/lang_coverage_validation_report.txt);
-- print() is unreliable under this headless invocation, so the file is the
-- record.
local report_path = os.getenv('LANG_COV_VAL_REPORT') or '/tmp/lang_coverage_validation_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end

local val_passed, val_failed = 0, 0
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end

local root = vim.fn.getcwd()

-- Independent registry readers (do NOT go through coverage_gen.collect).

local function uniq_sorted(list)
    local seen, out = {}, {}
    for _, v in ipairs(list) do
        if not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    table.sort(out)
    return out
end

local function flatten_stages(stages)
    local names = {}
    for _, stage in ipairs(stages) do
        if type(stage) == 'string' then
            names[#names + 1] = stage
        else
            for _, alt in ipairs(stage) do
                names[#names + 1] = alt
            end
        end
    end
    return uniq_sorted(names)
end

---@return table<string, string[]> filetype -> sorted lsp stems, independently scanned
local function scan_lsp()
    local by_ft = {}
    local files = vim.fn.globpath(root .. '/lsp', '*_ls.lua', false, true)
    for _, path in ipairs(files) do
        local stem = vim.fn.fnamemodify(path, ':t:r')
        local chunk = loadfile(path)
        if chunk then
            local ok, cfg = pcall(chunk)
            if ok and type(cfg) == 'table' and type(cfg.filetypes) == 'table' then
                for _, ft in ipairs(cfg.filetypes) do
                    by_ft[ft] = by_ft[ft] or {}
                    by_ft[ft][#by_ft[ft] + 1] = stem
                end
            end
        end
    end
    for ft, stems in pairs(by_ft) do
        by_ft[ft] = uniq_sorted(stems)
    end
    return by_ft
end

---@return table<string, string[]> filetype -> sorted dap modules, independently parsed
local function scan_dap()
    local by_ft = {}
    local in_modules, in_ft, cur = false, false, nil
    for _, line in ipairs(vim.fn.readfile(root .. '/lua/dap/init.lua')) do
        if not in_modules then
            if line == 'local MODULES = {' then
                in_modules = true
            end
        elseif line == '}' then
            break
        elseif line:match('^%s*filetypes = {$') then
            cur, in_ft = {}, true
        elseif in_ft and line:match('^%s*},%s*$') then
            in_ft = false
        elseif in_ft then
            local q = line:match("^%s*'([^']+)',$")
            if q then
                cur[#cur + 1] = q
            end
        else
            local mod = line:match("^%s*module = '([^']+)',$")
            if mod and cur then
                for _, ft in ipairs(cur) do
                    by_ft[ft] = by_ft[ft] or {}
                    by_ft[ft][#by_ft[ft] + 1] = mod
                end
                cur = nil
            end
        end
    end
    for ft, mods in pairs(by_ft) do
        by_ft[ft] = uniq_sorted(mods)
    end
    return by_ft
end

local fmt_by_ft = require('formatters').formatters_by_ft
local lint_by_ft = require('linters').linters_by_ft
local lsp_by_ft = scan_lsp()
local dap_by_ft = scan_dap()
local bsp_set, browser_set = {}, {}
for _, ft in ipairs(require('bsp.servers').filetypes()) do
    bsp_set[ft] = true
end
for _, ft in ipairs({ 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }) do
    browser_set[ft] = true
end

-- V1-V3: the manifest equals the independently computed union exactly.
do
    local union = {}
    for ft in pairs(fmt_by_ft) do
        union[ft] = true
    end
    for ft in pairs(lint_by_ft) do
        union[ft] = true
    end
    for ft in pairs(lsp_by_ft) do
        union[ft] = true
    end
    for ft in pairs(dap_by_ft) do
        union[ft] = true
    end
    for ft in pairs(bsp_set) do
        union[ft] = true
    end
    for ft in pairs(browser_set) do
        union[ft] = true
    end
    local manifest = require('config.lang.coverage')
    val_check(
        vim.tbl_count(manifest) == vim.tbl_count(union),
        ('manifest count %d equals independent union %d'):format(vim.tbl_count(manifest), vim.tbl_count(union))
    )
    local missing, extra = {}, {}
    for ft in pairs(union) do
        if manifest[ft] == nil then
            missing[#missing + 1] = ft
        end
    end
    for ft in pairs(manifest) do
        if union[ft] == nil then
            extra[#extra + 1] = ft
        end
    end
    val_check(#missing == 0, 'no union filetype missing from the manifest (' .. table.concat(missing, ',') .. ')')
    val_check(#extra == 0, 'no manifest filetype outside the union (' .. table.concat(extra, ',') .. ')')
end

-- V4-V8: spot-check 10 filetypes (5 common, 5 obscure), field by field,
-- against the independently read registries.
local function entry_matches(ft)
    local manifest = require('config.lang.coverage')
    local e = manifest[ft]
    if type(e) ~= 'table' then
        return false, 'no manifest entry'
    end
    local function same(a, b)
        return table.concat(a, '\0') == table.concat(b, '\0')
    end
    if not same(e.formatters, flatten_stages(fmt_by_ft[ft] or {})) then
        return false, 'formatters differ'
    end
    if not same(e.linters, uniq_sorted(lint_by_ft[ft] or {})) then
        return false, 'linters differ'
    end
    if not same(e.lsp, lsp_by_ft[ft] or {}) then
        return false, 'lsp differ'
    end
    if not same(e.dap, dap_by_ft[ft] or {}) then
        return false, 'dap differ'
    end
    if e.bsp ~= (bsp_set[ft] == true) then
        return false, 'bsp flag differs'
    end
    if e.browser ~= (browser_set[ft] == true) then
        return false, 'browser flag differs'
    end
    return true, ''
end

local function check_pair(ft1, ft2, label)
    local ok1, d1 = entry_matches(ft1)
    local ok2, d2 = entry_matches(ft2)
    val_check(
        ok1 and ok2,
        ('spot-check %s: %s%s / %s%s'):format(
            label,
            ft1,
            ok1 and '' or ('(' .. d1 .. ')'),
            ft2,
            ok2 and '' or ('(' .. d2 .. ')')
        )
    )
end

check_pair('lua', 'python', 'common/1')
check_pair('javascript', 'rust', 'common/2')
check_pair('go', 'aiken', 'common+obscure')
check_pair('bzl', 'glimmer', 'obscure/1')
check_pair('postgresql', 'sqlite', 'obscure/2')

-- V9-V10: the config boots with the stubs gone and the requires pruned.
do
    local ok_lang, err_lang = pcall(require, 'config.lang')
    local ok_tlang, err_tlang = pcall(require, 'types.lang')
    local ok_tcore, err_tcore = pcall(require, 'types.core')
    val_check(
        ok_lang and ok_tlang and ok_tcore,
        ('config boots: config.lang/types.lang/types.core (%s%s%s)'):format(
            ok_lang and '' or tostring(err_lang):sub(1, 60),
            ok_tlang and '' or tostring(err_tlang):sub(1, 60),
            ok_tcore and '' or tostring(err_tcore):sub(1, 60)
        )
    )
    local problems = require('linters').validate()
    val_check(#problems == 0, 'linters.validate() clean (' .. #problems .. ' problems)')
end

-- V11-V12: the manifest loads with the documented shape, keys sorted.
do
    local manifest = require('config.lang.coverage')
    local bad = 0
    for _, e in pairs(manifest) do
        if
            type(e.formatters) ~= 'table'
            or type(e.linters) ~= 'table'
            or type(e.lsp) ~= 'table'
            or type(e.dap) ~= 'table'
            or type(e.bsp) ~= 'boolean'
            or type(e.browser) ~= 'boolean'
        then
            bad = bad + 1
        end
    end
    val_check(bad == 0, 'every manifest entry carries the six typed fields')
    local ordered = {}
    for _, line in ipairs(vim.fn.readfile(root .. '/lua/config/lang/coverage.lua')) do
        local ft = line:match("^%s+%['([^']+)'%] = {$")
        if ft then
            ordered[#ordered + 1] = ft
        end
    end
    local sorted = {}
    for _, ft in ipairs(ordered) do
        sorted[#sorted + 1] = ft
    end
    table.sort(sorted)
    local in_order = #ordered == vim.tbl_count(manifest) and table.concat(ordered, '\0') == table.concat(sorted, '\0')
    val_check(in_order, ('manifest keys sorted in file order (%d keys)'):format(#ordered))
end

emit(string.format('RESULT: %d passed, %d failed', val_passed, val_failed))
local fh = assert(io.open(report_path, 'w'))
fh:write(table.concat(log_lines, '\n') .. '\n')
fh:close()
if val_failed > 0 then
    vim.cmd('cquit 1')
end
vim.cmd('quit')
