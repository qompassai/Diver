-- lua/utils/sf/init.lua
local M = {}

local did_setup = false

function M.setup()
    if did_setup then
        return
    end
    did_setup = true

    require('utils.sf.commands').register()

    local autocmds = require('utils.sf.autocmds')
    if autocmds and autocmds.setup then
        autocmds.setup()
    end

    local mappings = require('utils.sf.mappings')
    if mappings and mappings.setup then
        mappings.setup()
    end
end

return M