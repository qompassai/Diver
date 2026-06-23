local util = require('utils.sf.util')
local apex = require('utils.sf.apex')

local M = {}

function M.lwc_bundle_dir(file)
    return file:match('(.*/lwc/[^/]+)')
end

function M.aura_bundle_dir(file)
    return file:match('(.*/aura/[^/]+)')
end

function M.deploy_current()
    if not util.ensure_sf() or not util.has_file() then
        return
    end

    local file = util.current_file()
    local lwc = M.lwc_bundle_dir(file)
    local aura = M.aura_bundle_dir(file)

    if lwc then
        util.open_term_cmd('sf project deploy start --source-dir ' .. util.shellescape(lwc), 16)
        return
    end

    if aura then
        util.open_term_cmd('sf project deploy start --source-dir ' .. util.shellescape(aura), 16)
        return
    end

    util.open_term_cmd('sf project deploy start --source-dir ' .. util.shellescape(file), 16)
end

function M.retrieve_current()
    if not util.ensure_sf() or not util.has_file() then
        return
    end
    local file = util.current_file()
    util.open_term_cmd('sf project retrieve start --source-dir ' .. util.shellescape(file), 16)
end

function M.smart_action()
    if not util.ensure_sf() or not util.has_file() then
        return
    end

    local file = util.current_file()
    local ft = util.filetype()

    if ft == 'apex' and apex.is_apex_script(file) then
        apex.run_current_file()
        return
    end

    if ft == 'apex' and apex.is_apex_metadata(file) then
        M.deploy_current()
        return
    end

    if M.lwc_bundle_dir(file) or M.aura_bundle_dir(file) then
        M.deploy_current()
        return
    end

    M.deploy_current()
end

return M
