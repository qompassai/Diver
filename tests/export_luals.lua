-- Export the trusted local Diver LuaLS profile for a completed batch check.
-- Usage: DIVER_ROOT=/path/to/Diver ACP_CHECK_CONFIG=/tmp/acp-check.json nvim --headless -u NONE -l tests/export_luals.lua
local root = assert(vim.env.DIVER_ROOT, 'Set DIVER_ROOT to your trusted Diver checkout')
local output = assert(vim.env.ACP_CHECK_CONFIG, 'Set ACP_CHECK_CONFIG to the output JSON path')
local chunk, load_error = loadfile(vim.fs.joinpath(root, 'lsp/lua_ls.lua'))
assert(chunk, load_error)
local loaded = chunk()
assert(type(loaded.settings) == 'table' and type(loaded.settings.Lua) == 'table')
local profile = vim.deepcopy(loaded.settings.Lua)
profile.runtime =
    { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua', '?.lua', '?/init.lua' } }
profile.workspace =
    { library = { vim.env.VIMRUNTIME }, checkThirdParty = false, maxPreload = 10000 }
profile.type = vim.tbl_extend('force', profile.type or {}, {
    castNumberToInteger = false,
    checkTableShape = true,
    inferParamType = true,
    weakNilCheck = false,
    weakUnionCheck = false,
})
profile.diagnostics.groupSeverity['type-check'] = 'Error'
profile.diagnostics.groupFileStatus['type-check'] = 'Any'
profile.diagnostics.severity['undefined-field'] = 'Error'
profile.diagnostics.workspaceDelay = 0
local file, open_error = io.open(output, 'w')
assert(file, open_error)
assert(file:write(vim.json.encode(profile)))
assert(file:close())
