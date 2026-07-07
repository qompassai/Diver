local api = vim.api
local fn = vim.fn
local uv = vim.uv
local M = {}
---@param msg string
---@param level? integer
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, {
    title = 'sf-data',
  })
end
local function shellescape(s)
  return fn.shellescape(s)
end
local function file_exists(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == 'file' or false
end
local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end
local function systemlist(cmd)
  local out = fn.systemlist(cmd)
  local code = vim.v.shell_error
  return out, code
end

local function open_scratch(name, lines, filetype)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, name)
  api.nvim_set_current_buf(buf)
  api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  api.nvim_set_option_value('swapfile', false, { buf = buf })
  if filetype and filetype ~= '' then
    api.nvim_set_option_value('filetype', filetype, { buf = buf })
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  return buf
end

local function run_and_show(cmd, name, filetype)
  local out, code = systemlist(cmd)
  open_scratch(name, out, filetype or 'text')
  if code ~= 0 then
    notify(('Command failed: %s'):format(cmd), vim.log.levels.ERROR)
  end
end

local function prompt_org()
  return fn.input('Target org alias (blank = default): ')
end

local function org_flag(org)
  if org and org ~= '' then
    return ' --target-org ' .. shellescape(org)
  end
  return ''
end

local function split_csv_line(line)
  local out, cur, i, in_quotes = {}, '', 1, false
  while i <= #line do
    local c = line:sub(i, i)
    if c == '"' then
      local nxt = line:sub(i + 1, i + 1)
      if in_quotes and nxt == '"' then
        cur = cur .. '"'
        i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif c == ',' and not in_quotes then
      out[#out + 1] = trim(cur)
      cur = ''
    else
      cur = cur .. c
    end
    i = i + 1
  end
  out[#out + 1] = trim(cur)
  for idx, v in ipairs(out) do
    if v:sub(1, 1) == '"' and v:sub(-1) == '"' then
      out[idx] = v:sub(2, -2)
    end
  end
  return out
end

local function unique(list)
  local seen, out = {}, {}
  for _, item in ipairs(list) do
    if item ~= '' and not seen[item] then
      seen[item] = true
      out[#out + 1] = item
    end
  end
  return out
end

local function sanitize_field_name(name)
  local s = trim(name)
  s = s:gsub('^"(.*)"$', '%1')
  s = s:gsub('%s+', '_')
  s = s:gsub('[^%w_:.]', '')
  return s
end

local function csv_headers(path)
  local lines = fn.readfile(path, '', 1)
  if not lines or #lines == 0 then
    return nil, 'CSV file is empty'
  end
  local headers = split_csv_line(lines[1])
  for i, h in ipairs(headers) do
    headers[i] = sanitize_field_name(h)
  end
  headers = unique(headers)
  if #headers == 0 then
    return nil, 'No CSV headers found'
  end
  return headers
end

local function xlsx_headers(path, sheet)
  local py = table.concat({
    'import json, sys',
    'from openpyxl import load_workbook',
    'path = sys.argv[1]',
    'sheet = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None',
    'wb = load_workbook(path, read_only=True, data_only=True)',
    'ws = wb[sheet] if sheet else wb[wb.sheetnames[0]]',
    'row = next(ws.iter_rows(min_row=1, max_row=1, values_only=True), None)',
    'headers = [] if row is None else ["" if v is None else str(v) for v in row]',
    'print(json.dumps({"sheet": ws.title, "headers": headers}))',
  }, '; ')

  local cmd = 'python3 -c ' .. shellescape(py) .. ' ' .. shellescape(path)
  if sheet and sheet ~= '' then
    cmd = cmd .. ' ' .. shellescape(sheet)
  end

  local out = fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, 'Failed reading XLSX: ' .. trim(out)
  end

  local ok, decoded = pcall(vim.json.decode, out)
  if not ok or type(decoded) ~= 'table' then
    return nil, 'Could not parse XLSX header output'
  end

  local headers = decoded.headers or {}
  for i, h in ipairs(headers) do
    headers[i] = sanitize_field_name(h)
  end
  headers = unique(headers)

  if #headers == 0 then
    return nil, 'No XLSX headers found'
  end

  return headers, decoded.sheet
end

local function infer_external_id(headers)
  for _, h in ipairs(headers) do
    local l = h:lower()
    if l == 'id' or l:match('external[_ ]?id') or l:match('__c$') then
      return h
    end
  end
end
local function build_soql_from_headers(object_name, headers, source_path, sheet_name)
  local fields = table.concat(headers, ',\n  ')
  local ext_id = infer_external_id(headers)

  local lines = {
    ('-- source: %s'):format(source_path),
  }

  if sheet_name and sheet_name ~= '' then
    lines[#lines + 1] = ('-- sheet: %s'):format(sheet_name)
  end

  lines[#lines + 1] = ('SELECT\n  %s\nFROM %s\nLIMIT 200'):format(fields, object_name)
  lines[#lines + 1] = ''
  lines[#lines + 1] = '-- Data Loader / Bulk API upsert notes'
  lines[#lines + 1] = '-- Your CSV/XLSX import needs a matching ID or External ID column for upsert.'
  lines[#lines + 1] = ext_id and ('-- Suggested match field: ' .. ext_id)
    or '-- Suggested match field: <set an External ID or Id column>'
  lines[#lines + 1] = ''
  lines[#lines + 1] = '-- Field mapping template'

  for _, h in ipairs(headers) do
    lines[#lines + 1] = ('%s=%s'):format(h, h)
  end

  return lines
end

local function detect_headers(path, sheet)
  local lower = path:lower()
  if lower:match('%.csv$') then
    return csv_headers(path)
  end
  if lower:match('%.xlsx$') then
    return xlsx_headers(path, sheet)
  end
  if lower:match('%.xls$') then
    return nil, 'Legacy .xls is not supported yet; save as .xlsx or .csv first'
  end
  return nil, 'Unsupported file type: ' .. path
end

function M.delete_bulk(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local path = args[1] or fn.input('CSV path: ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('SObject API name: ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    return notify('CSV path and sObject are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data delete bulk --file '
    .. shellescape(path)
    .. ' --sobject '
    .. shellescape(object_name)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-delete-bulk', 'json')
end
function M.delete_record(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local object_name = args[1] or fn.input('SObject API name: ')
  local record_id = args[2] or fn.input('Record Id: ')
  local org = args[3] or prompt_org()
  if object_name == '' or record_id == '' then
    return notify('SObject and record Id are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data delete record --sobject '
    .. shellescape(object_name)
    .. ' --record-id '
    .. shellescape(record_id)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-delete-record', 'json')
end
function M.delete_resume(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local job_id = args[1] or fn.input('Bulk delete job id: ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    return notify('Job id is required', vim.log.levels.WARN)
  end
  local cmd = 'sf data delete resume --job-id ' .. shellescape(job_id) .. org_flag(org)
  run_and_show(cmd, 'sf://data-delete-resume', 'json')
end

function M.import_bulk(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local path = args[1] or fn.input('CSV path: ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('SObject API name: ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    return notify('CSV path and sObject are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data import bulk --file '
    .. shellescape(path)
    .. ' --sobject '
    .. shellescape(object_name)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-import-bulk', 'json')
end

function M.import_resume(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local job_id = args[1] or fn.input('Bulk import job id: ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    return notify('Job id is required', vim.log.levels.WARN)
  end
  local cmd = 'sf data import resume --job-id ' .. shellescape(job_id) .. org_flag(org)
  run_and_show(cmd, 'sf://data-import-resume', 'json')
end

function M.import_tree(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local path = args[1] or fn.input('JSON plan/file path: ', fn.getcwd() .. '/', 'file')
  local org = args[2] or prompt_org()
  if path == '' then
    return notify('JSON input path is required', vim.log.levels.WARN)
  end
  local cmd = 'sf data import tree --files ' .. shellescape(path) .. org_flag(org)
  run_and_show(cmd, 'sf://data-import-tree', 'json')
end

function M.query(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local query = table.concat(args, ' ')
  if query == '' then
    query = fn.input('SOQL query: ')
  end
  if query == '' then
    return notify('SOQL query is required', vim.log.levels.WARN)
  end
  local org = prompt_org()
  local cmd = 'sf data query --query ' .. shellescape(query) .. ' --result-format json' .. org_flag(org)
  run_and_show(cmd, 'sf://data-query', 'json')
end

function M.resume(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local job_id = args[1] or fn.input('Bulk job id: ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    return notify('Job id is required', vim.log.levels.WARN)
  end
  local cmd = 'sf data resume --job-id ' .. shellescape(job_id) .. org_flag(org)
  run_and_show(cmd, 'sf://data-resume', 'json')
end

function M.search(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local sosl = table.concat(args, ' ')
  if sosl == '' then
    sosl = fn.input('SOSL search: ')
  end
  if sosl == '' then
    return notify('SOSL search is required', vim.log.levels.WARN)
  end
  local org = prompt_org()
  local cmd = 'sf data search --query ' .. shellescape(sosl) .. ' --result-format json' .. org_flag(org)
  run_and_show(cmd, 'sf://data-search', 'json')
end

function M.soql_from_file(opts)
  opts = opts or {}
  local args = opts.fargs or {}

  local path = args[1] or fn.input('CSV/XLSX path: ', fn.getcwd() .. '/', 'file')
  if path == '' then
    return notify('No file selected', vim.log.levels.WARN)
  end

  path = fn.fnamemodify(path, ':p')
  if not file_exists(path) then
    return notify('File not found: ' .. path, vim.log.levels.ERROR)
  end

  local object_name = args[2] or fn.input('Salesforce object API name: ')
  if object_name == '' then
    return notify('Object API name is required', vim.log.levels.WARN)
  end

  local sheet = args[3] or ''
  local headers, meta = detect_headers(path, sheet)
  if not headers then
    local err = meta or 'Failed to detect headers'
    return notify(err, vim.log.levels.ERROR)
  end
  open_scratch(
    ('soql://%s'):format(fn.fnamemodify(path, ':t')),
    build_soql_from_headers(object_name, headers, path, meta),
    'sql'
  )

  notify(('Generated SOQL starter from %s (%d fields)'):format(fn.fnamemodify(path, ':t'), #headers))
end

function M.soql_from_current_file()
  local path = fn.expand('%:p')
  if path == '' then
    return notify('Current buffer is not a file', vim.log.levels.WARN)
  end
  M.soql_from_file({ fargs = { path } })
end

function M.update_bulk(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local path = args[1] or fn.input('CSV path: ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('SObject API name: ')
  local org = args[3] or prompt_org()
  if path == '' or object_name == '' then
    return notify('CSV path and sObject are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data update bulk --file '
    .. shellescape(path)
    .. ' --sobject '
    .. shellescape(object_name)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-update-bulk', 'json')
end

function M.update_record(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local object_name = args[1] or fn.input('SObject API name: ')
  local record_id = args[2] or fn.input('Record Id: ')
  local values = args[3] or fn.input('Values (Field=Value,Field2=Value2): ')
  local org = args[4] or prompt_org()
  if object_name == '' or record_id == '' or values == '' then
    return notify('SObject, record Id, and values are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data update record --sobject '
    .. shellescape(object_name)
    .. ' --record-id '
    .. shellescape(record_id)
    .. ' --values '
    .. shellescape(values)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-update-record', 'json')
end

function M.upsert_bulk(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local path = args[1] or fn.input('CSV path: ', fn.getcwd() .. '/', 'file')
  local object_name = args[2] or fn.input('SObject API name: ')
  local external_id = args[3] or fn.input('External ID field: ')
  local org = args[4] or prompt_org()
  if path == '' or object_name == '' or external_id == '' then
    return notify('CSV path, sObject, and external ID field are required', vim.log.levels.WARN)
  end
  local cmd = 'sf data upsert bulk --file '
    .. shellescape(path)
    .. ' --sobject '
    .. shellescape(object_name)
    .. ' --external-id '
    .. shellescape(external_id)
    .. org_flag(org)
  run_and_show(cmd, 'sf://data-upsert-bulk', 'json')
end

function M.upsert_resume(opts)
  opts = opts or {}
  local args = opts.fargs or {}
  local job_id = args[1] or fn.input('Bulk upsert job id: ')
  local org = args[2] or prompt_org()
  if job_id == '' then
    return notify('Job id is required', vim.log.levels.WARN)
  end
  local cmd = 'sf data upsert resume --job-id ' .. shellescape(job_id) .. org_flag(org)
  run_and_show(cmd, 'sf://data-upsert-resume', 'json')
end

return M
