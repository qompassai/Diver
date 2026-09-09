-- /qompassai/Diver/lua/utils/dev/sf/data.lua
-- Qompass AI Diver Salesforce Data Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local core = require('utils.dev.sf.core')

local M = {}

---@param path string
---@return boolean
local function file_exists(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == 'file'
end

---@param value string
---@return string
local function trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

---@param output? string
---@return string[]
local function output_lines(output)
  if type(output) ~= 'string' or output == '' then
    return {}
  end
  return vim.split(output, '\n', {
    plain = true,
    trimempty = true,
  })
end

---@param name string
---@param lines string[]
---@param filetype? string
---@return integer
local function open_scratch(name, lines, filetype)
  local existing = fn.bufnr(name)
  if type(existing) == 'number' and existing > 0 and api.nvim_buf_is_valid(existing) then
    api.nvim_buf_delete(existing, { force = true })
  end
  local bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(bufnr, name)
  api.nvim_set_option_value('bufhidden', 'wipe', {
    buf = bufnr,
  })
  api.nvim_set_option_value('swapfile', false, {
    buf = bufnr,
  })
  if type(filetype) == 'string' and filetype ~= '' then
    api.nvim_set_option_value('filetype', filetype, {
      buf = bufnr,
    })
  end
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  api.nvim_set_option_value('modifiable', false, {
    buf = bufnr,
  })
  api.nvim_set_current_buf(bufnr)
  return bufnr
end

---@param result vim.SystemCompleted
---@return string
local function result_error(result)
  local message = result.stderr
  if type(message) ~= 'string' or message == '' then
    message = result.stdout
  end
  if type(message) ~= 'string' or message == '' then
    message = ('Salesforce data command exited with status %d'):format(result.code)
  end
  return vim.trim(message)
end

---@param argv string[]
---@param name string
---@param filetype? string
local function run_and_show(argv, name, filetype)
  if not core.ensure() then
    return
  end
  vim.system(argv, {
    cwd = core.root(),
    text = true,
  }, function(result)
    vim.schedule(function()
      local output = result.stdout
      if type(output) ~= 'string' or output == '' then
        output = result.stderr
      end
      open_scratch(name, output_lines(output), filetype or 'text')
      if result.code ~= 0 then
        core.notify(result_error(result), vim.log.levels.ERROR)
      end
    end)
  end)
end

---@return string
local function prompt_org()
  return fn.input('Target org alias (blank = default)> ')
end

---@param argv string[]
---@param org? string
local function append_org(argv, org)
  if type(org) == 'string' and org ~= '' then
    argv[#argv + 1] = '--target-org'
    argv[#argv + 1] = org
  end
end

---@param line string
---@return string[]
local function split_csv_line(line)
  local fields = {}
  local current = ''
  local index = 1
  local quoted = false
  while index <= #line do
    local character = line:sub(index, index)
    if character == '"' then
      local following = line:sub(index + 1, index + 1)
      if quoted and following == '"' then
        current = current .. '"'
        index = index + 1
      else
        quoted = not quoted
      end
    elseif character == ',' and not quoted then
      fields[#fields + 1] = trim(current)
      current = ''
    else
      current = current .. character
    end
    index = index + 1
  end
  fields[#fields + 1] = trim(current)
  return fields
end

---@param values string[]
---@return string[]
local function unique(values)
  local seen = {}
  local result = {}
  for _, value in ipairs(values) do
    if value ~= '' and not seen[value] then
      seen[value] = true
      result[#result + 1] = value
    end
  end
  return result
end

---@param name any
---@return string
local function sanitize_field_name(name)
  local value = trim(tostring(name or ''))
  value = value:gsub('^"(.*)"$', '%1')
  value = value:gsub('%s+', '_')
  return (value:gsub('[^%w_.]', ''))
end

---@param path string
---@return string[]?
---@return string?
local function csv_headers(path)
  local ok, lines = pcall(fn.readfile, path, '', 1)
  if not ok or type(lines) ~= 'table' then
    return nil, 'Could not read CSV file: ' .. path
  end
  if type(lines[1]) ~= 'string' then
    return nil, 'CSV file is empty'
  end
  local headers = split_csv_line(lines[1])
  for index, header in ipairs(headers) do
    headers[index] = sanitize_field_name(header)
  end
  headers = unique(headers)
  if #headers == 0 then
    return nil, 'No CSV headers found'
  end
  return headers
end

---@param path string
---@param sheet? string
---@return string[]?
---@return string?
local function xlsx_headers(path, sheet)
  if fn.executable('python3') ~= 1 then
    return nil, 'Python 3 is required to inspect XLSX files'
  end
  local script = table.concat({
    'import json, sys',
    'from openpyxl import load_workbook',
    'path = sys.argv[1]',
    'sheet = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None',
    'workbook = load_workbook(path, read_only=True, data_only=True)',
    'worksheet = workbook[sheet] if sheet else workbook[workbook.sheetnames[0]]',
    'row = next(worksheet.iter_rows(min_row=1, max_row=1, values_only=True), None)',
    'headers = [] if row is None else ["" if value is None else str(value) for value in row]',
    'print(json.dumps({"sheet": worksheet.title, "headers": headers}))',
  }, '; ')
  local argv = { 'python3', '-c', script, path }
  if type(sheet) == 'string' and sheet ~= '' then
    argv[#argv + 1] = sheet
  end
  local result = vim.system(argv, { text = true }):wait()
  if result.code ~= 0 then
    return nil, 'Failed reading XLSX: ' .. result_error(result)
  end
  local ok, decoded = pcall(vim.json.decode, result.stdout or '')
  if not ok or type(decoded) ~= 'table' or type(decoded.headers) ~= 'table' then
    return nil, 'Could not parse XLSX header output'
  end
  local headers = {}
  for _, header in ipairs(decoded.headers) do
    headers[#headers + 1] = sanitize_field_name(header)
  end
  headers = unique(headers)
  if #headers == 0 then
    return nil, 'No XLSX headers found'
  end
  return headers, type(decoded.sheet) == 'string' and decoded.sheet or nil
end

---@param headers string[]
---@return string?
local function infer_external_id(headers)
  for _, header in ipairs(headers) do
    local lower = header:lower()
    if lower == 'id' or lower:match('external_?id') then
      return header
    end
  end
  return nil
end

---@param object_name string
---@param headers string[]
---@param source_path string
---@param sheet_name? string
---@return string[]
local function build_soql_from_headers(object_name, headers, source_path, sheet_name)
  local lines = {
    ('-- source: %s'):format(source_path),
  }
  if type(sheet_name) == 'string' and sheet_name ~= '' then
    lines[#lines + 1] = ('-- sheet: %s'):format(sheet_name)
  end
  lines[#lines + 1] = ('SELECT\n  %s\nFROM %s\nLIMIT 200'):format(table.concat(headers, ',\n  '), object_name)
  lines[#lines + 1] = ''
  lines[#lines + 1] = '-- Data Loader / Bulk API upsert notes'
  lines[#lines + 1] = '-- The input needs an Id or configured External ID column for upsert.'
  local external_id = infer_external_id(headers)
  lines[#lines + 1] = external_id and ('-- Possible match field: ' .. external_id)
    or '-- Match field: <set an Id or External ID column>'
  lines[#lines + 1] = ''
  lines[#lines + 1] = '-- Field mapping template'
  for _, header in ipairs(headers) do
    lines[#lines + 1] = ('%s=%s'):format(header, header)
  end
  return lines
end

---@param path string
---@param sheet? string
---@return string[]?
---@return string?
local function detect_headers(path, sheet)
  local lower = path:lower()
  if lower:match('%.csv$') then
    return csv_headers(path)
  elseif lower:match('%.xlsx$') then
    return xlsx_headers(path, sheet)
  elseif lower:match('%.xls$') then
    return nil, 'Legacy .xls is unsupported; save the workbook as .xlsx or .csv'
  end
  return nil, 'Unsupported file type: ' .. path
end

---@param opts? SfCommandArgs
function M.create_record(opts)
  local args = core.get_args(opts)
  local object_name = args[1] or fn.input('sObject API name> ')
  local values = args[2] or fn.input('Values (Field=Value Field2=Value)> ')
  local org = args[3] or prompt_org()
  if object_name == '' or values == '' then
    core.notify('sObject and values are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'create',
    'record',
    '--sobject',
    object_name,
    '--values',
    values,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-create-record', 'json')
end

---@param opts? SfCommandArgs
function M.delete_bulk(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('CSV path> ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('sObject API name> ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    core.notify('CSV path and sObject are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'delete',
    'bulk',
    '--file',
    path,
    '--sobject',
    object_name,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-delete-bulk', 'json')
end

---@param opts? SfCommandArgs
function M.delete_record(opts)
  local args = core.get_args(opts)
  local object_name = args[1] or fn.input('sObject API name> ')
  local record_id = args[2] or fn.input('Record ID> ')
  local org = args[3] or prompt_org()
  if object_name == '' or record_id == '' then
    core.notify('sObject and record ID are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'delete',
    'record',
    '--sobject',
    object_name,
    '--record-id',
    record_id,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-delete-record', 'json')
end

---@param opts? SfCommandArgs
function M.delete_resume(opts)
  local args = core.get_args(opts)
  local job_id = args[1] or fn.input('Bulk delete job ID> ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    core.notify('Job ID is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'delete', 'resume', '--job-id', job_id, '--json' }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-delete-resume', 'json')
end

---@param opts? SfCommandArgs
function M.export_tree(opts)
  local query = table.concat(core.get_args(opts), ' ')
  if query == '' then
    query = fn.input('SOQL query or query-file path> ')
  end
  if query == '' then
    core.notify('SOQL query or query-file path is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'export', 'tree', '--query', query, '--json' }
  append_org(argv, prompt_org())
  run_and_show(argv, 'sf://data-export-tree', 'json')
end

---@param opts? SfCommandArgs
function M.get_record(opts)
  local args = core.get_args(opts)
  local object_name = args[1] or fn.input('sObject API name> ')
  local record_id = args[2] or fn.input('Record ID> ')
  local org = args[3] or prompt_org()
  if object_name == '' or record_id == '' then
    core.notify('sObject and record ID are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'get',
    'record',
    '--sobject',
    object_name,
    '--record-id',
    record_id,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-get-record', 'json')
end

---@param opts? SfCommandArgs
function M.import_bulk(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('CSV path> ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('sObject API name> ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    core.notify('CSV path and sObject are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'import',
    'bulk',
    '--file',
    path,
    '--sobject',
    object_name,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-import-bulk', 'json')
end

---@param opts? SfCommandArgs
function M.import_resume(opts)
  local args = core.get_args(opts)
  local job_id = args[1] or fn.input('Bulk import job ID> ')
  if job_id == '' then
    core.notify('Job ID is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'import', 'resume', '--job-id', job_id, '--json' }
  run_and_show(argv, 'sf://data-import-resume', 'json')
end

---@param opts? SfCommandArgs
function M.import_tree(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('JSON data file(s), comma-separated> ', fn.getcwd() .. '/', 'file')
  local org = args[2] or prompt_org()
  if path == '' then
    core.notify('At least one JSON data file is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'import', 'tree', '--files', path, '--json' }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-import-tree', 'json')
end

---@param opts? SfCommandArgs
function M.query(opts)
  local query = table.concat(core.get_args(opts), ' ')
  if query == '' then
    query = fn.input('SOQL query> ')
  end
  if query == '' then
    core.notify('SOQL query is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'query', '--query', query, '--json' }
  append_org(argv, prompt_org())
  run_and_show(argv, 'sf://data-query', 'json')
end

function M.query_buffer()
  local query = trim(table.concat(api.nvim_buf_get_lines(0, 0, -1, false), ' '))
  if query == '' then
    core.notify('Current buffer contains no SOQL query', vim.log.levels.WARN)
    return
  end
  M.query({ fargs = { query } })
end

---@param opts? SfCommandArgs
function M.query_file(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('SOQL file> ', fn.expand('%:p'), 'file')
  local org = args[2] or prompt_org()
  if path == '' then
    core.notify('SOQL file is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'query', '--file', path, '--json' }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-query-file', 'json')
end

---@param opts? SfCommandArgs
function M.resume(opts)
  local args = core.get_args(opts)
  local job_id = args[1] or fn.input('Bulk job ID> ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    core.notify('Job ID is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'resume', '--job-id', job_id, '--json' }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-resume', 'json')
end

---@param opts? SfCommandArgs
function M.search(opts)
  local query = table.concat(core.get_args(opts), ' ')
  if query == '' then
    query = fn.input('SOSL search> ')
  end
  if query == '' then
    core.notify('SOSL search is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'search', '--query', query, '--json' }
  append_org(argv, prompt_org())
  run_and_show(argv, 'sf://data-search', 'json')
end

---@param opts? SfCommandArgs
function M.soql_from_file(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('CSV/XLSX path> ', fn.getcwd() .. '/', 'file')
  if path == '' then
    core.notify('No file selected', vim.log.levels.WARN)
    return
  end
  path = fn.fnamemodify(path, ':p')
  if not file_exists(path) then
    core.notify('File not found: ' .. path, vim.log.levels.ERROR)
    return
  end
  local object_name = args[2] or fn.input('Salesforce object API name> ')
  if object_name == '' then
    core.notify('Object API name is required', vim.log.levels.WARN)
    return
  end
  local headers, metadata = detect_headers(path, args[3])
  if not headers then
    core.notify(metadata or 'Failed to detect headers', vim.log.levels.ERROR)
    return
  end
  open_scratch(
    ('soql://%s'):format(fn.fnamemodify(path, ':t')),
    build_soql_from_headers(object_name, headers, path, metadata),
    'sql'
  )
  core.notify(('Generated SOQL starter from %s (%d fields)'):format(fn.fnamemodify(path, ':t'), #headers))
end

function M.soql_from_current_file()
  local path = fn.expand('%:p')
  if path == '' then
    core.notify('Current buffer is not a file', vim.log.levels.WARN)
    return
  end
  M.soql_from_file({ fargs = { path } })
end

---@param opts? SfCommandArgs
function M.update_bulk(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('CSV path> ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('sObject API name> ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    core.notify('CSV path and sObject are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'update',
    'bulk',
    '--file',
    path,
    '--sobject',
    object_name,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-update-bulk', 'json')
end

---@param opts? SfCommandArgs
function M.update_record(opts)
  local args = core.get_args(opts)
  local object_name = args[1] or fn.input('sObject API name> ')
  local record_id = args[2] or fn.input('Record ID> ')
  local values = args[3] or fn.input('Values (Field=Value Field2=Value)> ')
  local org = args[4] or prompt_org()
  if object_name == '' or record_id == '' or values == '' then
    core.notify('sObject, record ID, and values are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'update',
    'record',
    '--sobject',
    object_name,
    '--record-id',
    record_id,
    '--values',
    values,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-update-record', 'json')
end

---@param opts? SfCommandArgs
function M.upsert_bulk(opts)
  local args = core.get_args(opts)
  local path = args[1] or fn.input('CSV path> ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('sObject API name> ')
  local external_id = args[3] or fn.input('External ID field> ')
  local org = args[4] or prompt_org()
  if path == '' or object_name == '' or external_id == '' then
    core.notify('CSV path, sObject, and external ID field are required', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'data',
    'upsert',
    'bulk',
    '--file',
    path,
    '--sobject',
    object_name,
    '--external-id',
    external_id,
    '--json',
  }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-upsert-bulk', 'json')
end

---@param opts? SfCommandArgs
function M.upsert_resume(opts)
  local args = core.get_args(opts)
  local job_id = args[1] or fn.input('Bulk upsert job ID> ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    core.notify('Job ID is required', vim.log.levels.WARN)
    return
  end
  local argv = { 'sf', 'data', 'upsert', 'resume', '--job-id', job_id, '--json' }
  append_org(argv, org)
  run_and_show(argv, 'sf://data-upsert-resume', 'json')
end

M.commands = {
  {
    name = 'SfDataCreateRecord',
    fn = M.create_record,
    opts = { desc = 'Create a Salesforce record', nargs = '*' },
  },
  {
    name = 'SfDataDeleteBulk',
    fn = M.delete_bulk,
    opts = { desc = 'Bulk-delete Salesforce records', nargs = '*' },
  },
  {
    name = 'SfDataDeleteRecord',
    fn = M.delete_record,
    opts = { desc = 'Delete a Salesforce record', nargs = '*' },
  },
  {
    name = 'SfDataDeleteResume',
    fn = M.delete_resume,
    opts = { desc = 'Resume a bulk delete job', nargs = '*' },
  },
  {
    name = 'SfDataExportTree',
    fn = M.export_tree,
    opts = { desc = 'Export records as an sObject tree', nargs = '*' },
  },
  {
    name = 'SfDataGetRecord',
    fn = M.get_record,
    opts = {
      desc = 'Get a Salesforce record',
      nargs = '*',
    },
  },
  {
    name = 'SfDataImportBulk',
    fn = M.import_bulk,
    opts = {
      desc = 'Bulk-import Salesforce records',
      nargs = '*',
    },
  },
  {
    name = 'SfDataImportResume',
    fn = M.import_resume,
    opts = { desc = 'Resume a bulk import job', nargs = '*' },
  },
  {
    name = 'SfDataImportTree',
    fn = M.import_tree,
    opts = { desc = 'Import an sObject tree', nargs = '*' },
  },
  {
    name = 'SfDataQuery',
    fn = M.query,
    opts = { desc = 'Run a SOQL query', nargs = '*' },
  },
  {
    name = 'SfDataQueryBuffer',
    fn = M.query_buffer,
    opts = {
      desc = 'Run SOQL from the current buffer',
      nargs = 0,
    },
  },
  { name = 'SfDataQueryFile', fn = M.query_file, opts = {
    desc = 'Run SOQL from a file',
    nargs = '*',
  } },
  {
    name = 'SfDataResume',
    fn = M.resume,
    opts = { desc = 'Resume a Salesforce bulk data job', nargs = '*' },
  },
  { name = 'SfDataSearch', fn = M.search, opts = {
    desc = 'Run a SOSL search',
    nargs = '*',
  } },
  {
    name = 'SfDataSoqlFromFile',
    fn = M.soql_from_file,
    opts = {
      desc = 'Generate SOQL from CSV/XLSX headers',
      nargs = '*',
    },
  },
  {
    name = 'SfDataSoqlFromCurrentFile',
    fn = M.soql_from_current_file,
    opts = {
      desc = 'Generate SOQL from the current CSV/XLSX file',
      nargs = 0,
    },
  },
  {
    name = 'SfDataUpdateBulk',
    fn = M.update_bulk,
    opts = { desc = 'Bulk-update Salesforce records', nargs = '*' },
  },
  {
    name = 'SfDataUpdateRecord',
    fn = M.update_record,
    opts = {
      desc = 'Update a Salesforce record',
      nargs = '*',
    },
  },
  {
    name = 'SfDataUpsertBulk',
    fn = M.upsert_bulk,
    opts = {
      desc = 'Bulk-upsert Salesforce records',
      nargs = '*',
    },
  },
  {
    name = 'SfDataUpsertResume',
    fn = M.upsert_resume,
    opts = {
      desc = 'Resume a bulk upsert job',
      nargs = '*',
    },
  },
}

return M