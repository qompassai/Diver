-- Native mapping loader; set Leader and LocalLeader before calling setup().
-- SPDX-License-Identifier: Apache-2.0
local core = require('mappings._core')
local M = {}
local MODULES = {
    'aimap',
    'cicdmap',
    'datamap',
    'ddxmap',
    'disable',
    'genmap',
    'langmap',
    'lintmap',
    'lspmap',
}
local loaded = {}

function M.teardown()
    for index = #loaded, 1, -1 do
        local entry = loaded[index]
        if type(entry.module.teardown) == 'function' then
            local ok, err = pcall(entry.module.teardown)
            if not ok then
                core.notify(entry.name .. ': ' .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end
    loaded = {}
end

---@param opts? table Module options keyed by filename without .lua.
---@return boolean ok, string[] errors
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'Mapping options must be a table')
    M.teardown()
    local errors = {}
    for _, name in ipairs(MODULES) do
        if opts[name] ~= false then
            local ok, module = pcall(require, 'mappings.' .. name)
            if ok and type(module) == 'table' and type(module.setup) == 'function' then
                loaded[#loaded + 1] = { name = name, module = module }
                ok, module = pcall(module.setup, opts[name])
            else
                ok, module = false, tostring(module)
            end
            if not ok then
                errors[#errors + 1] = name .. ': ' .. tostring(module)
            end
        end
    end
    if #errors > 0 then
        core.notify(table.concat(errors, '\n'), vim.log.levels.ERROR)
    end
    return #errors == 0, errors
end

return M
