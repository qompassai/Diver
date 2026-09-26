-- /qompassai/Diver/tests/lua/scip_wiring.lua
-- Self-test for the SCIP language wiring (scip.lang, scip.query,
-- ai.builder.scip, ai.dataaccess.scip, ai.retrieval.scip, refactor.scip).
--
-- Plain words: this script checks that every language task resolves to
-- the right SCIP indexer (including multi-language indexers like java
-- covering kotlin), that index status/ensure behave honestly, that the
-- data layer blocks bad roots, and that the builder/refactor/retrieval
-- helpers load and answer. It runs headless via `nvim -l`; it is not
-- loaded at startup.
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

-- scip.lang: dynamic language resolution.
local lang = require('scip.lang')

local langs = lang.languages()
check(#langs >= 30, 'covers 30+ languages, got ' .. #langs)

local function indexer_for(name)
    local match, err = lang.for_language(name)
    assert(match ~= nil, 'no indexer for ' .. name .. ': ' .. tostring(err))
    return match.indexer
end

check(indexer_for('rust') == 'rust', 'rust -> rust')
check(indexer_for('kotlin') == 'java', 'kotlin -> java indexer')
check(indexer_for('scala') == 'java', 'scala -> java indexer')
check(indexer_for('javascript') == 'typescript', 'javascript -> typescript indexer')
check(indexer_for('c++') == 'clang', 'c++ alias -> clang indexer')
check(indexer_for('c#') == 'dotnet', 'c# alias -> dotnet indexer')
check(indexer_for('cuda') == 'clang', 'cuda -> clang indexer')
check(indexer_for('lua') == 'lua', 'lua indexer enabled')
check(indexer_for('nix') == 'nix', 'nix indexer enabled')
check(indexer_for('tex') == 'latex', 'tex -> latex indexer enabled')

local cobol, cobol_err = lang.for_language('cobol')
check(cobol == nil and cobol_err ~= nil, 'unknown language rejected')

local empty, empty_err = lang.for_language('')
check(empty == nil and empty_err ~= nil, 'empty language rejected')

local multi = lang.multi_language()
check(multi.java ~= nil and #multi.java >= 3, 'java is multi-language')
check(multi.clang ~= nil and #multi.clang >= 3, 'clang is multi-language')
check(multi.typescript ~= nil, 'typescript is multi-language')

lang.invalidate()
local after = lang.for_language('rust')
check(after ~= nil and after.indexer == 'rust', 'map rebuilds after invalidate')

-- scip.query: read side.
local query = require('scip.query')
check(query.index_path('/tmp/proj') == '/tmp/proj/index.scip', 'index_path joins correctly')

local status, status_err = query.status({ root = '/tmp', language = 'rust' })
check(status ~= nil, 'status resolves: ' .. tostring(status_err))
check(status.indexer == 'rust', 'status names the indexer')
check(status.exists == false, 'missing index reports exists=false')
check(status.fresh == false, 'missing index reports fresh=false')

local bad_status, bad_err = query.status({ root = '/tmp', language = 'cobol' })
check(bad_status == nil and bad_err ~= nil, 'status rejects unknown language')

-- ai.dataaccess.scip: managed metadata, validated roots.
local da_scip = require('ai.dataaccess.scip')

local entry, entry_err = da_scip.status_for_root('/tmp', 'python')
check(entry ~= nil, 'dataaccess status: ' .. tostring(entry_err))
check(entry.indexer == 'python', 'dataaccess names the indexer')
check(entry.root == '/tmp', 'dataaccess normalizes the root')

check(da_scip.status_for_root('../evil', 'python') == nil, 'traversal root blocked')
check(da_scip.status_for_root('relative/path', 'python') == nil, 'relative root blocked')
check(da_scip.status_for_root('', 'python') == nil, 'empty root blocked')

local inv = da_scip.inventory({
    { root = '/tmp', language = 'rust' },
    { root = '../evil', language = 'rust' },
    { root = '/tmp', language = 'go' },
})
check(#inv == 2, 'inventory skips invalid roots, got ' .. #inv)

-- ai.retrieval.scip: candidate text.
local ret_scip = require('ai.retrieval.scip')
check(
    ret_scip.text_of({ name = 'foo', kind = 'function', language = 'rust' }) == 'function foo rust',
    'text_of formats candidate'
)
check(ret_scip.text_of(nil) == '', 'text_of handles nil')

-- ai.builder.scip: coverage.
local builder_scip = require('ai.builder.scip')
local coverage = builder_scip.coverage()
check(#coverage >= 30, 'builder coverage lists 30+ languages')

local sync_ctx, sync_err = builder_scip.prepare_sync({ language = 'cobol' })
check(sync_ctx == nil and sync_err ~= nil, 'prepare_sync rejects unknown language')

local no_lang_ctx, no_lang_err = builder_scip.prepare_sync({})
check(no_lang_ctx == nil and no_lang_err == nil, 'prepare_sync without language is nil, nil')

-- refactor.scip: pre-flight degrades gracefully.
local refactor_scip = require('refactor.scip')
vim.cmd('enew')
vim.bo.filetype = 'rust'
local preflight = refactor_scip.preflight()
check(type(preflight) == 'table', 'preflight returns a table')
check(preflight.language == 'rust', 'preflight names the language')
check(type(preflight.lsp_files) == 'number', 'preflight counts LSP files')
check(refactor_scip.confirm(preflight) == true, 'confirm proceeds')

-- scip.init exposes the new modules.
local scip = require('scip')
check(scip.lang == lang, 'scip.lang exposed')
check(scip.query == query, 'scip.query exposed')

print(('PASS: %d checks'):format(passed))
