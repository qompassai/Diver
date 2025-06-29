-- qompassai/Diver/lua/config/cicd/init.lua
-- Qompass AI Diver CICD Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

function M.setup_all(opts)
    local modules = {'ansible', 'build', 'json', 'shell'}
    for _, module_name in ipairs(modules) do
        local ok, module = pcall(require, 'config.cicd.' .. module_name)
        if ok and type(module.setup) == 'function' then
            module.setup(opts)
        end
    end
end

return M
