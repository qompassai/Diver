.lua
-- #################################################################
-- ~/.config/nvim/lua/linters/v8r.lua
-- Native v8r JSON / JSON5 / YAML / TOML Schema Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/chris48s/v8r
---@source https://chris48s.github.io/v8r/configuration/
--
-- Requires an installed v8r executable on Neovim's PATH. Never invokes npx
-- or installs packages during linting. Native Linter / LintContext interface.
-- Register 'v8r' for json, jsonc, json5, yaml and toml as appropriate; parser
-- selection is owned by v8r and may require a customCatalog parser override.
-- Run on saved files, normally BufWritePost. The runner must skip unnamed
-- buffers and reject results after edits. stdin is not supported by this CLI.
--
-- The JSON report has JSON Pointer instance paths, not source coordinates.
-- Findings are file-level diagnostics at line/column zero; no guessed ranges.
-- Multi-document YAML indices are retained (zero-based, as reported by v8r).
-- Schema keywords, schema locations and instance paths are retained; arbitrary
-- input values from AJV params are not copied into diagnostic metadata.
--
-- Project config, plugins, catalogs and ignore files remain authoritative.
-- Remote schemas/catalogs can be fetched by v8r; this is not an offline mode.
-- Use trusted JavaScript configs and plugins. Automatic scans use existing
-- v8r caching policy, with a 60-second runner timeout and bounded parser.
-- Optional: NVIM_V8R_SCHEMA=/absolute/path/schema.json (or a schema URL).
-- Relative override paths resolve against the selected project working dir.
-- V8R_CONFIG_FILE retains its upstream meaning; paths in that file are still
-- resolved against the working directory, not its own directory.
-- Logs remain on stderr; only stdout is decoded as JSON. Operational failures
-- produce a diagnostic even when the report has no detailed error message.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local json = vim.json

local SOURCE = 'v8r'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_RESULTS = 1024
local CONFIG_MARKERS = {
  '.v8rrc', '.v8rrc.json', '.v8rrc.yaml', '.v8rrc.yml',
  '.v8rrc.js', '.v8rrc.cjs', 'v8r.config.js', 'v8r.config.cjs',
}
local ROOT_MARKERS = { CONFIG_MARKERS, 'package.json', '.git' }

---@param value any
---@return string?
local function string_value(value)
  if type(value) == 'string' and value ~= '' then
    return value
  end

  return nil
end

---@param context LintContext
---@return string
local function project_root(context)
  local filename = string_value(context.filename)

  -- Prefer the nearest v8r configuration, even inside a larger repository.
  if filename ~= nil then
    local configured = fs.root(filename, CONFIG_MARKERS)

    if configured ~= nil then
      return fs.normalize(configured)
    end
  end

  local root = string_value(context.root)

  if root ~= nil then
    return fs.normalize(root)
  end

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if detected ~= nil then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if parent ~= nil and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(string_value(context.cwd) or vim.fn.getcwd())
end

---@param path string
---@param cwd string
---@return string
local function absolute_path(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end

  return fs.normalize(path)
end

---@param path string
---@param cwd string
---@return string
local function canonical_path(path, cwd)
  local absolute = absolute_path(path, cwd)

  return uv.fs_realpath(absolute) or absolute
end

---@param value string
---@return string
local function clean_message(value)
  local text = vim.trim(value:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '))

  if #text > MAX_MESSAGE_BYTES then
    local finish = MAX_MESSAGE_BYTES - 3

    -- Do not split a UTF-8 codepoint when truncating.
    while finish > 0 do
      local byte = text:byte(finish + 1)

      if byte == nil or byte < 128 or byte >= 192 then
        break
      end

      finish = finish - 1
    end

    text = text:sub(1, finish) .. '...'
  end

  return text
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status_diagnostic(context, code, message)
  return {
    bufnr = context.bufnr,
    code = code,
    col = 0,
    lnum = 0,
    message = message,
    severity = diagnostic.severity.WARN,
    source = SOURCE,
  }
end

---@param path string
---@param cwd string
---@return string
local function relative_path(path, cwd)
  local target_parts = vim.split(absolute_path(path, cwd), '/', { trimempty = true })
  local root_parts = vim.split(fs.normalize(cwd), '/', { trimempty = true })
  local common = 0

  for index = 1, math.min(#target_parts, #root_parts) do
    if target_parts[index] ~= root_parts[index] then
      break
    end
    common = index
  end

  ---@type string[]
  local parts = {}
  for index = common + 1, #root_parts do
    parts[#parts + 1] = '..'
  end
  for index = common + 1, #target_parts do
    parts[#parts + 1] = target_parts[index]
  end
  return table.concat(parts, '/')
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'v8r parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'v8r parser requires context.bufnr')

  if context.modified then
    return { status_diagnostic(context, 'save-required', 'Save this buffer before running v8r; it validates the file on disk.') }
  end
  local filename = string_value(context.filename)
  if filename == nil then
    return { status_diagnostic(context, 'filename-required', 'Save this buffer before running v8r.') }
  end
  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'v8r output exceeded the 16 MiB parser limit; validation results are incomplete.') }
  end
  local ok, decoded = pcall(json.decode, output)
  if not ok or type(decoded) ~= 'table' or type(decoded.results) ~= 'table' or not vim.islist(decoded.results) then
    return { status_diagnostic(context, 'invalid-report', 'v8r returned no valid JSON results. Check configuration, ignored files, CLI compatibility and the timeout.') }
  end

  local cwd = project_root(context)
  local target = canonical_path(filename, string_value(context.cwd) or cwd)
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local matched = false
  local malformed = false
  local limited = #decoded.results > MAX_RESULTS
  local processed = 0

  for index = 1, math.min(#decoded.results, MAX_RESULTS) do
    local result = decoded.results[index]
    if type(result) ~= 'table' or string_value(result.fileLocation) == nil then
      malformed = true
    elseif canonical_path(result.fileLocation, cwd) == target then
      matched = true
      local schema = string_value(result.schemaLocation)
      local document = result.documentIndex
      local prefix = ''
      if type(document) == 'number' and document >= 0 and document < MAX_RESULTS and document == math.floor(document) then
        prefix = string.format('Document [%d]: ', document)
      else
        document = nil
      end
      if result.valid == false and type(result.errors) == 'table' and vim.islist(result.errors) and #result.errors > 0 then
        for error_index = 1, #result.errors do
          processed = processed + 1
          if processed > MAX_DIAGNOSTICS or #diagnostics >= MAX_DIAGNOSTICS then
            limited = true
            break
          end
          local issue = result.errors[error_index]
          if type(issue) ~= 'table' or string_value(issue.message) == nil then
            malformed = true
          else
            local pointer = string_value(issue.instancePath) or ''
            local keyword = string_value(issue.keyword) or 'schema'
            local text = prefix .. (pointer == '' and '<root>' or pointer) .. ': ' .. issue.message
            if type(issue.params) == 'table' then
              local missing = string_value(issue.params.missingProperty)
              local additional = string_value(issue.params.additionalProperty)
              if missing ~= nil then
                text = text .. ' (missing property: ' .. missing .. ')'
              elseif additional ~= nil then
                text = text .. ' (additional property: ' .. additional .. ')'
              end
            end
            diagnostics[#diagnostics + 1] = {
              bufnr = context.bufnr,
              code = clean_message(keyword),
              col = 0,
              lnum = 0,
              message = clean_message(text),
              severity = diagnostic.severity.ERROR,
              source = SOURCE,
              user_data = {
                instance_path = clean_message(pointer),
                schema_path = type(issue.schemaPath) == 'string' and clean_message(issue.schemaPath) or nil,
                schema = schema and clean_message(schema) or nil,
                document_index = document,
              },
            }
          end
        end
      elseif result.valid ~= true or result.code ~= 0 then
        diagnostics[#diagnostics + 1] = status_diagnostic(context, 'validation-incomplete', prefix .. 'v8r could not complete validation. Check input syntax, schema discovery, schema references and network access.')
      end
      if #diagnostics >= MAX_DIAGNOSTICS then
        if index < #decoded.results then
          limited = true
        end
        break
      end
    end
  end

  if not matched then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'no-result', 'v8r returned no result for this file. Check ignore rules and filename matching.')
  end
  if malformed then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'malformed-result', 'Some v8r report entries could not be parsed; results are incomplete.')
  end
  if limited then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'result-limit', 'v8r reached the editor parser limit; run the CLI for a complete report.')
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'v8r arguments require LintContext')
  local filename = string_value(context.filename)
  assert(filename ~= nil, 'v8r requires a saved filename')
  local cwd = project_root(context)
  local path = relative_path(absolute_path(filename, string_value(context.cwd) or cwd), cwd)
  -- v8r passes positional arguments through node-glob even without a shell.
  local backslash = string.char(92)
  local pattern = path:gsub('[*?%[%]{}()!+@' .. backslash .. ']', function(character)
    return backslash .. character
  end)
  ---@type string[]
  local args = { '--output-format', 'json' }
  local schema = string_value(vim.env.NVIM_V8R_SCHEMA)
  if schema ~= nil then
    args[#args + 1] = '--schema'
    args[#args + 1] = schema
  end
  -- Prefix prevents option-like filenames; v8r's positional parser rejects --.
  args[#args + 1] = './' .. pattern
  return args
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'v8r',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}