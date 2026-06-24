-- lua/utils/sf/data.lua
-- Wraps: @salesforce/plugin-data
local util = require('utils.sf.util')
local M = {}

-- :SfDataQuery
function M.query()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local soql = vim.fn.input('SOQL> ')
    if soql == '' then
        return
    end
    util.open_term_cmd('sf data query --query ' .. util.shellescape(soql) .. ' --result-format table', 20)
end

-- :SfDataQueryBuffer  -- run entire buffer as SOQL
function M.query_buffer()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local soql = table.concat(lines, ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if soql == '' then
        vim.notify('[sf] Buffer is empty', vim.log.levels.WARN)
        return
    end
    util.open_term_cmd('sf data query --query ' .. util.shellescape(soql) .. ' --result-format table', 20)
end

-- :SfDataQueryFile  -- run a .soql file
function M.query_file()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local f = util.current_file()
    if not f:match('%.soql$') then
        vim.notify('[sf] Current file is not a .soql file', vim.log.levels.WARN)
        return
    end
    util.open_term_cmd('sf data query --file ' .. util.shellescape(f) .. ' --result-format table', 20)
end

-- :SfDataGetRecord
function M.get_record()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local sobject = vim.fn.input('SObject> ')
    if sobject == '' then
        return
    end
    local record_id = vim.fn.input('Record ID> ')
    if record_id == '' then
        return
    end
    util.open_term_cmd(
        'sf data get record --sobject ' .. util.shellescape(sobject) .. ' --record-id ' .. util.shellescape(record_id),
        20
    )
end

-- :SfDataCreateRecord
function M.create_record()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local sobject = vim.fn.input('SObject> ')
    if sobject == '' then
        return
    end
    local values = vim.fn.input('Field=Value pairs (space-separated)> ')
    if values == '' then
        return
    end
    util.open_term_cmd(
        'sf data create record --sobject ' .. util.shellescape(sobject) .. ' --values ' .. util.shellescape(values),
        20
    )
end

-- :SfDataDeleteRecord
function M.delete_record()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local sobject = vim.fn.input('SObject> ')
    if sobject == '' then
        return
    end
    local record_id = vim.fn.input('Record ID> ')
    if record_id == '' then
        return
    end
    util.open_term_cmd(
        'sf data delete record --sobject '
            .. util.shellescape(sobject)
            .. ' --record-id '
            .. util.shellescape(record_id),
        20
    )
end

-- :SfDataExportTree
function M.export_tree()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local soql = vim.fn.input('SOQL (with child relationships)> ')
    if soql == '' then
        return
    end
    local prefix = vim.fn.input('Output prefix (default: export)> ')
    prefix = prefix ~= '' and prefix or 'export'
    util.open_term_cmd(
        'sf data export tree --query '
            .. util.shellescape(soql)
            .. ' --prefix '
            .. util.shellescape(prefix)
            .. ' --output-dir .',
        20
    )
end

-- :SfDataUpsertBulk
function M.upsert_bulk()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local sobject = vim.fn.input('SObject> ')
    if sobject == '' then
        return
    end
    local ext_id = vim.fn.input('External ID field> ')
    if ext_id == '' then
        return
    end
    local csv_file = vim.fn.input('CSV file path> ', '', 'file')
    if csv_file == '' then
        return
    end
    util.open_term_cmd(
        'sf data upsert bulk --sobject '
            .. util.shellescape(sobject)
            .. ' --external-id '
            .. util.shellescape(ext_id)
            .. ' --file '
            .. util.shellescape(csv_file)
            .. ' --wait 10',
        30
    )
end

return M