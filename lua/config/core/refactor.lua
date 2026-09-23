-- /qompassai/Diver/lua/config/core/refactor.lua
-- Native Diver refactor facade configuration; no third-party refactor plugin.
-- SPDX-License-Identifier: Apache-2.0
local M = {}
local defaults = {
    commands = true,
    debug = { block_count_max = 1024, cleanup_line_max = 250000, output_location = 'below' },
}
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'refactor options must be a table')
    local ok, facade = pcall(require, 'refactor')
    if not ok or type(facade) ~= 'table' or type(facade.setup) ~= 'function' then
        return nil, 'Diver lua/refactor/ is unavailable: ' .. tostring(facade)
    end
    return facade.setup(vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {}))
end
-- Keep the original require-time configuration contract.
local ok, err = M.setup()
if ok == nil and err then
    vim.notify(err, vim.log.levels.WARN)
end
return M
