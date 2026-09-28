-- lua/config/lang/coverage_gen.lua
-- Coverage manifest generator: reads the live tooling registries and emits
-- lua/config/lang/coverage.lua, the sorted filetype -> tooling map.
--
-- Plain-language version: Diver knows hundreds of filetypes across five
-- tooling registries (formatters, linters, LSP servers, DAP adapters, build
-- servers) plus the browser tooling. This module walks each registry, merges
-- them into one sorted table, and writes it out, so tests and tooling can ask
-- "what does Diver know how to do for filetype X?" without re-scanning.
--
-- Regenerate with :LangCoverage (registered by M.setup()), or headless:
--   nvim --headless -i NONE -u <repo>/init.lua -l scripts/gen_lang_coverage.lua
--
-- The output is deterministic: every key and every list is sorted, so
-- regenerating with unchanged inputs produces a byte-identical file.
---@module 'config.lang.coverage_gen'

local M = {}

---@class LangCoverageRaw
---@field formatters table<string, (string|string[])[]> filetype -> formatter pipeline stages
---@field linters table<string, string[]> filetype -> linter names
---@field lsp table<string, string[]> filetype -> server module stems (e.g. 'bash_ls')
---@field lsp_skipped string[] lsp/*.lua files with no usable filetypes table
---@field dap table<string, string[]> filetype -> dap module names
---@field bsp table<string, boolean> filetype set from bsp.servers
---@field browser table<string, boolean> filetype set covered by dev.browser

---@class LangCoverageEntry
---@field formatters string[] sorted formatter names for the filetype
---@field linters string[] sorted linter names for the filetype
---@field lsp string[] sorted server module stems for the filetype
---@field dap string[] sorted dap module names for the filetype
---@field bsp boolean true when a BSP build server claims the filetype
---@field browser boolean true when the browser tooling covers the filetype

---@class LangCoverageStats
---@field filetypes integer filetypes in the emitted manifest
---@field bytes integer bytes written
---@field path string manifest path written
---@field lsp_files integer lsp/*_ls.lua files seen
---@field lsp_loaded integer files contributing a filetypes table
---@field lsp_skipped integer files without a usable filetypes table
---@field dap_entries integer DAP MODULES entries parsed

-- dev.browser (bidi + cdp) is the web-page driving surface. It declares no
-- filetype registry in code, so the covered set is asserted here: the JS/TS
-- filetypes a web developer edits while driving a page.
local BROWSER_FILETYPES = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
}

-- Generated lines stay inside the repo stylua column_width (120).
local RENDER_COLS_MAX = 112

---Derive the repo root from this module's own path; never trust the cwd.
---@return string root absolute path of the diver checkout
local function repo_root()
    local source = debug.getinfo(1, 'S').source
    local root = type(source) == 'string' and source:match('^@(.+)/lua/config/lang/coverage_gen%.lua$')
    assert(root ~= nil, 'coverage_gen: cannot derive repo root from ' .. tostring(source))
    assert(vim.fn.isdirectory(root .. '/lsp') == 1, 'coverage_gen: no lsp/ under ' .. root)
    return root
end

---@param t table
---@return string[] sorted keys
local function sorted_keys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

---@param list string[]
---@return string[] # deduplicated, sorted copy
local function uniq_sorted(list)
    assert(type(list) == 'table', 'uniq_sorted needs a list')
    local seen = {}
    ---@type string[]
    local out = {}
    for _, value in ipairs(list) do
        assert(type(value) == 'string', 'coverage lists hold strings')
        if not seen[value] then
            seen[value] = true
            out[#out + 1] = value
        end
    end
    table.sort(out)
    return out
end

---@param stages (string|string[])[] formatter pipeline stages; nested lists pick one alternative
---@return string[] # flattened, deduplicated, sorted formatter names
local function flatten_stages(stages)
    assert(type(stages) == 'table', 'formatter stages must be a table')
    ---@type string[]
    local names = {}
    for _, stage in ipairs(stages) do
        if type(stage) == 'string' then
            names[#names + 1] = stage
        elseif type(stage) == 'table' then
            for _, alternative in ipairs(stage) do
                assert(type(alternative) == 'string', 'formatter alternative must be a string')
                names[#names + 1] = alternative
            end
        else
            error('formatter stage must be a string or a list, got ' .. type(stage))
        end
    end
    return uniq_sorted(names)
end

---@param path string absolute path of lua/dap/init.lua
---@return table<string, string[]> filetype -> sorted dap module names
---@return integer entry_count MODULES entries parsed
local function parse_dap_modules(path)
    local lines = vim.fn.readfile(path)
    assert(#lines > 0, 'coverage_gen: cannot read ' .. path)
    ---@type table<string, string[]>
    local by_ft = {}
    local in_modules = false
    local in_ft_block = false
    ---@type string[]|nil
    local cur_fts = nil
    local entry_count = 0
    for _, line in ipairs(lines) do
        if not in_modules then
            if line == 'local MODULES = {' then
                in_modules = true
            end
        elseif line == '}' then
            break
        elseif line:match('^%s*filetypes = {$') then
            cur_fts, in_ft_block = {}, true
        elseif in_ft_block and line:match('^%s*},%s*$') then
            in_ft_block = false
        elseif in_ft_block then
            local quoted = line:match("^%s*'([^']+)',$")
            if quoted ~= nil then
                cur_fts[#cur_fts + 1] = quoted
            end
        else
            local mod = line:match("^%s*module = '([^']+)',$")
            if mod ~= nil then
                assert(cur_fts ~= nil and #cur_fts > 0, 'coverage_gen: dap entry without filetypes: ' .. mod)
                entry_count = entry_count + 1
                for _, ft in ipairs(cur_fts) do
                    by_ft[ft] = by_ft[ft] or {}
                    by_ft[ft][#by_ft[ft] + 1] = mod
                end
                cur_fts, in_ft_block = nil, false
            end
        end
    end
    assert(entry_count > 0, 'coverage_gen: no DAP MODULES entries parsed from ' .. path)
    for ft, mods in pairs(by_ft) do
        by_ft[ft] = uniq_sorted(mods)
    end
    return by_ft, entry_count
end

---Read every real registry. Expensive but honest: this is the loader-based
---measurement the manifest derives from.
---@return LangCoverageRaw raw
---@return LangCoverageStats stats
function M.collect()
    local formatters_mod = require('formatters')
    assert(type(formatters_mod.formatters_by_ft) == 'table', 'formatters_by_ft missing')
    local linters_mod = require('linters')
    assert(type(linters_mod.linters_by_ft) == 'table', 'linters_by_ft missing')

    ---@type LangCoverageRaw
    local raw = {
        formatters = {},
        linters = {},
        lsp = {},
        lsp_skipped = {},
        dap = {},
        bsp = {},
        browser = {},
    }

    for ft, stages in pairs(formatters_mod.formatters_by_ft) do
        assert(type(ft) == 'string', 'formatter filetype keys must be strings')
        assert(type(stages) == 'table', 'formatters_by_ft[' .. ft .. '] must be a stage list')
        raw.formatters[ft] = stages
    end
    for ft, names in pairs(linters_mod.linters_by_ft) do
        assert(type(ft) == 'string', 'linter filetype keys must be strings')
        assert(type(names) == 'table', 'linters_by_ft[' .. ft .. '] must be a list')
        raw.linters[ft] = uniq_sorted(names)
    end

    local root = repo_root()
    local lsp_files = vim.fn.globpath(root .. '/lsp', '*_ls.lua', false, true)
    table.sort(lsp_files)
    local lsp_loaded = 0
    for _, path in ipairs(lsp_files) do
        local stem = vim.fn.fnamemodify(path, ':t:r')
        local chunk = loadfile(path)
        local ok, cfg = false, nil
        if chunk ~= nil then
            ok, cfg = pcall(chunk)
        end
        if ok and type(cfg) == 'table' and type(cfg.filetypes) == 'table' then
            lsp_loaded = lsp_loaded + 1
            for _, ft in ipairs(cfg.filetypes) do
                assert(type(ft) == 'string', stem .. ': filetype must be a string')
                raw.lsp[ft] = raw.lsp[ft] or {}
                raw.lsp[ft][#raw.lsp[ft] + 1] = stem
            end
        else
            raw.lsp_skipped[#raw.lsp_skipped + 1] = stem
        end
    end
    table.sort(raw.lsp_skipped)
    for ft, stems in pairs(raw.lsp) do
        raw.lsp[ft] = uniq_sorted(stems)
    end

    local dap_by_ft, dap_entries = parse_dap_modules(root .. '/lua/dap/init.lua')
    raw.dap = dap_by_ft

    local bsp_mod = require('dev.bsp.servers')
    local bsp_fts = bsp_mod.filetypes()
    assert(type(bsp_fts) == 'table', 'bsp.servers.filetypes() must return a list')
    for _, ft in ipairs(bsp_fts) do
        assert(type(ft) == 'string', 'bsp filetype must be a string')
        raw.bsp[ft] = true
    end
    for _, ft in ipairs(BROWSER_FILETYPES) do
        raw.browser[ft] = true
    end

    ---@type LangCoverageStats
    local stats = {
        filetypes = 0,
        bytes = 0,
        path = '',
        lsp_files = #lsp_files,
        lsp_loaded = lsp_loaded,
        lsp_skipped = #raw.lsp_skipped,
        dap_entries = dap_entries,
    }
    return raw, stats
end

---Merge raw registry data into the manifest. Pure: safe to call with fixtures.
---@param raw LangCoverageRaw
---@return table<string, LangCoverageEntry> manifest
function M.build(raw)
    assert(type(raw) == 'table', 'raw coverage data must be a table')
    ---@type table<string, LangCoverageEntry>
    local manifest = {}
    local function ensure(ft)
        assert(type(ft) == 'string' and #ft > 0, 'filetype keys must be non-empty strings')
        if manifest[ft] == nil then
            manifest[ft] = {
                formatters = {},
                linters = {},
                lsp = {},
                dap = {},
                bsp = false,
                browser = false,
            }
        end
        return manifest[ft]
    end
    for ft, stages in pairs(raw.formatters or {}) do
        ensure(ft).formatters = flatten_stages(stages)
    end
    for ft, names in pairs(raw.linters or {}) do
        ensure(ft).linters = uniq_sorted(names)
    end
    for ft, stems in pairs(raw.lsp or {}) do
        ensure(ft).lsp = uniq_sorted(stems)
    end
    for ft, mods in pairs(raw.dap or {}) do
        ensure(ft).dap = uniq_sorted(mods)
    end
    for ft in pairs(raw.bsp or {}) do
        ensure(ft).bsp = true
    end
    for ft in pairs(raw.browser or {}) do
        ensure(ft).browser = true
    end
    return manifest
end

---Guard: every filetype the registries know must appear in the manifest.
---Returns false + the missing list (loud) instead of silently dropping one.
---@param manifest table<string, LangCoverageEntry>
---@param raw LangCoverageRaw
---@return boolean ok
---@return string[]|nil missing filetypes with their source registry
function M.verify(manifest, raw)
    assert(type(manifest) == 'table', 'manifest must be a table')
    assert(type(raw) == 'table', 'raw coverage data must be a table')
    ---@type string[]
    local missing = {}
    local seen = {}
    local function check_source(map, source_name)
        for ft in pairs(map or {}) do
            if manifest[ft] == nil and not seen[ft] then
                seen[ft] = true
                missing[#missing + 1] = ft .. ' (' .. source_name .. ')'
            end
        end
    end
    check_source(raw.formatters, 'formatters')
    check_source(raw.linters, 'linters')
    check_source(raw.lsp, 'lsp')
    check_source(raw.dap, 'dap')
    check_source(raw.bsp, 'bsp')
    check_source(raw.browser, 'browser')
    table.sort(missing)
    if #missing > 0 then
        return false, missing
    end
    return true, nil
end

---@param s string filetype or tool name
---@return string # single-quoted, unless it holds a quote
local function qstr(s)
    assert(type(s) == 'string' and #s > 0, 'quoted names must be non-empty strings')
    if s:find("'", 1, true) ~= nil then
        return string.format('%q', s)
    end
    return "'" .. s .. "'"
end

---@param name string field name
---@param items string[] sorted items
---@param indent string
---@return string rendered field, one line when it fits
local function render_field(name, items, indent)
    assert(type(items) == 'table', name .. ' must render a list')
    if #items == 0 then
        return indent .. name .. ' = {},'
    end
    ---@type string[]
    local quoted = {}
    for _, item in ipairs(items) do
        quoted[#quoted + 1] = qstr(item)
    end
    local single = indent .. name .. ' = { ' .. table.concat(quoted, ', ') .. ' },'
    if #single <= RENDER_COLS_MAX then
        return single
    end
    ---@type string[]
    local lines = { indent .. name .. ' = {' }
    for _, q in ipairs(quoted) do
        lines[#lines + 1] = indent .. '    ' .. q .. ','
    end
    lines[#lines + 1] = indent .. '},'
    return table.concat(lines, '\n')
end

---@param ft string
---@param entry LangCoverageEntry
---@return string rendered manifest entry
local function render_entry(ft, entry)
    ---@type string[]
    local lines = { '    [' .. qstr(ft) .. '] = {' }
    for _, field in ipairs({ 'formatters', 'linters', 'lsp', 'dap' }) do
        lines[#lines + 1] = render_field(field, entry[field], '        ')
    end
    lines[#lines + 1] = '        bsp = ' .. tostring(entry.bsp) .. ','
    lines[#lines + 1] = '        browser = ' .. tostring(entry.browser) .. ','
    lines[#lines + 1] = '    },'
    return table.concat(lines, '\n')
end

---Render the manifest as deterministic Lua source. Sorted keys, sorted lists:
---identical input always yields identical bytes.
---@param manifest table<string, LangCoverageEntry>
---@param stats LangCoverageStats counts for the header comment
---@return string source
function M.emit(manifest, stats)
    assert(type(manifest) == 'table', 'manifest must be a table')
    assert(type(stats) == 'table', 'stats must be a table')
    local fts = sorted_keys(manifest)
    ---@type string[]
    local head = {
        '-- lua/config/lang/coverage.lua',
        '-- GENERATED FILE -- do not edit by hand. Regenerate with :LangCoverage or:',
        '--   nvim --headless -i NONE -u <repo>/init.lua -l scripts/gen_lang_coverage.lua',
        '--',
        '-- Tooling coverage manifest: every filetype known to at least one Diver',
        '-- tooling registry, mapped to its formatters, linters, LSP servers, DAP',
        '-- modules, and BSP/browser flags. Keys and all lists are sorted, so',
        '-- regenerating with unchanged inputs yields a byte-identical file.',
        '--',
        '-- Derivation (loader-based, measured inside headless nightly + full config):',
        "--   formatters: require('formatters').formatters_by_ft",
        "--   linters:    require('linters').linters_by_ft",
        '--   lsp:        loadable lsp/*_ls.lua files with a filetypes table',
        '--               ('
            .. stats.lsp_files
            .. ' files, '
            .. stats.lsp_loaded
            .. ' loaded, '
            .. stats.lsp_skipped
            .. ' skipped)',
        '--   dap:        filetype catalog (MODULES) in lua/dap/init.lua',
        '--               (' .. stats.dap_entries .. ' entries)',
        "--   bsp:        require('dev.bsp.servers').filetypes()",
        '--   browser:    lua/dev/browser (bidi+cdp) asserted JS/TS set',
        '-- Union filetypes: ' .. #fts,
        '',
        "---@module 'config.lang.coverage'",
        '--- Language tooling coverage: what Diver can do for each filetype.',
        '---',
        '--- Plain-language version: one entry per filetype Diver knows tooling',
        '--- for. Each entry lists the formatters, linters, LSP servers and DAP',
        '--- modules that handle the filetype, plus whether a build server (BSP)',
        '--- or the browser tooling covers it.',
        '--- Each entry is a LangCoverageEntry: the class is defined once in',
        '--- config.lang.coverage_gen (the module that builds this manifest),',
        '--- so the shape lives with the generator, not in generated text.',
        '',
        '---@type table<string, LangCoverageEntry>',
        'local M = {',
    }
    ---@type string[]
    local parts = { table.concat(head, '\n') }
    for _, ft in ipairs(fts) do
        parts[#parts + 1] = render_entry(ft, manifest[ft])
    end
    parts[#parts + 1] = '}'
    parts[#parts + 1] = ''
    parts[#parts + 1] = 'return M'
    parts[#parts + 1] = ''
    return table.concat(parts, '\n')
end

---Full pipeline: collect, build, verify, emit, write.
---@param out_path? string defaults to lua/config/lang/coverage.lua under the repo root
---@return table|nil stats
---@return string|nil err
function M.regenerate(out_path)
    local root = repo_root()
    local raw, stats = M.collect()
    local manifest = M.build(raw)
    local ok, missing = M.verify(manifest, raw)
    assert(ok, 'coverage manifest missing filetypes: ' .. table.concat(missing or {}, ', '))
    local text = M.emit(manifest, stats)
    local path = out_path or (root .. '/lua/config/lang/coverage.lua')
    assert(type(path) == 'string' and #path > 0, 'output path must be a non-empty string')
    local fh, ferr = io.open(path, 'w')
    if fh == nil then
        return nil, 'cannot write ' .. path .. ': ' .. tostring(ferr)
    end
    fh:write(text)
    fh:close()
    stats.path = path
    stats.bytes = #text
    stats.filetypes = #sorted_keys(manifest)
    return stats, nil
end

---Register the :LangCoverage command. Idempotent; safe to call at startup.
function M.setup()
    if M._setup_done then
        return
    end
    M._setup_done = true
    vim.api.nvim_create_user_command('LangCoverage', function()
        local ok, stats, rerr = pcall(M.regenerate)
        if ok and stats ~= nil then
            vim.notify(('LangCoverage: %d filetypes -> %s'):format(stats.filetypes, stats.path), vim.log.levels.INFO)
        else
            vim.notify('LangCoverage failed: ' .. tostring(rerr or stats), vim.log.levels.ERROR)
        end
    end, { desc = 'Regenerate lua/config/lang/coverage.lua from the live tooling registries' })
end

return M
