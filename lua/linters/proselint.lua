-- #################################################################
-- /qompassai/lua/linters/proselint.lua
-- Qompass AI Diver Native Proselint Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/amperser/proselint
---@source https://github.com/amperser/proselint/blob/main/docs/wire-schema.md
---@source https://neovim.io/doc/user/diagnostic/
---@source https://neovim.io/doc/user/lua/
--

local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 4096
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MAX_REPLACEMENT_BYTES = 4096
local SOURCE = 'proselint'

local ROOT_MARKERS = {
  'proselint.json',
  '.git',
}

---@param value any
---@return string?
local function string_value(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
end

---@param value string
---@return string
local function compact(value)
  return vim.trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(1, limit)
  end

  return value:sub(1, limit - 3) .. '...'
end

---@param value any
---@return integer?
local function integer_value(value)
  local number = tonumber(value)

  if number == nil then
    return nil
  end

  return math.floor(number)
end

---@param value any
---@return integer
local function zero_based(value)
  local integer = integer_value(value)

  if integer == nil or integer <= 1 then
    return 0
  end

  return integer - 1
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub('\27%[[%d;]*[mK]', '')
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(context.root)

  if context_root ~= nil then
    return fs.normalize(context_root)
  end

  local filename = string_value(context.filename)

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(vim.fn.getcwd())
end

---@param byte integer?
---@return boolean
local function continuation_byte(byte)
  return byte ~= nil and byte >= 0x80 and byte <= 0xBF
end

---@param value string
---@param index integer
---@return integer
local function utf8_width(value, index)
  local lead = value:byte(index)

  if lead == nil or lead < 0x80 then
    return 1
  end

  if lead >= 0xC2 and lead <= 0xDF and continuation_byte(value:byte(index + 1)) then
    return 2
  end

  if
    lead >= 0xE0
    and lead <= 0xEF
    and continuation_byte(value:byte(index + 1))
    and continuation_byte(value:byte(index + 2))
  then
    return 3
  end

  if
    lead >= 0xF0
    and lead <= 0xF4
    and continuation_byte(value:byte(index + 1))
    and continuation_byte(value:byte(index + 2))
    and continuation_byte(value:byte(index + 3))
  then
    return 4
  end

  return 1
end

---@param value string
---@return integer
local function character_count(value)
  local count = 0
  local index = 1

  while index <= #value do
    index = index + utf8_width(value, index)
    count = count + 1
  end

  return count
end

---@param value string
---@param character_index integer
---@return integer
local function byte_column(value, character_index)
  if character_index <= 0 then
    return 0
  end

  local characters = 0
  local index = 1

  while index <= #value and characters < character_index do
    index = index + utf8_width(value, index)
    characters = characters + 1
  end

  return math.min(index - 1, #value)
end

---@param context LintContext
---@return string[]?
local function buffer_lines(context)
  if not api.nvim_buf_is_valid(context.bufnr) then
    return nil
  end

  local ok, lines = pcall(api.nvim_buf_get_lines, context.bufnr, 0, -1, false)

  if not ok or type(lines) ~= 'table' then
    return nil
  end

  return lines
end

---@param lines string[]
---@param offset integer
---@return integer, integer
local function position_from_offset(lines, offset)
  if #lines == 0 then
    return 0, 0
  end

  local remaining = math.max(0, offset)

  for line_index = 1, #lines do
    local line = lines[line_index]
    local line_characters = character_count(line)

    if remaining <= line_characters then
      return line_index - 1, byte_column(line, remaining)
    end

    remaining = remaining - line_characters

    if line_index < #lines then
      remaining = remaining - 1
    end
  end

  local last = lines[#lines]

  return #lines - 1, #last
end

---@param lines string[]?
---@param pos any
---@return integer, integer
local function position_from_pos(lines, pos)
  if type(pos) ~= 'table' then
    return 0, 0
  end

  local lnum = zero_based(pos[1])
  local character_column = zero_based(pos[2])

  if lines == nil or #lines == 0 then
    return lnum, character_column
  end

  lnum = math.min(lnum, #lines - 1)

  return lnum, byte_column(lines[lnum + 1], character_column)
end

---@param lines string[]?
---@param pos any
---@param span any
---@return integer, integer, integer, integer
local function diagnostic_range(lines, pos, span)
  if lines ~= nil and type(span) == 'table' then
    local start_offset = integer_value(span[1])
    local end_offset = integer_value(span[2])

    if start_offset ~= nil and end_offset ~= nil then
      start_offset = math.max(0, start_offset - 1)
      end_offset = math.max(start_offset, end_offset - 1)

      local lnum, col = position_from_offset(lines, start_offset)
      local end_lnum, end_col = position_from_offset(lines, end_offset)

      return lnum, col, end_lnum, end_col
    end
  end

  local lnum, col = position_from_pos(lines, pos)

  return lnum, col, lnum, col + 1
end

---@class ProselintWireError
---@field code? integer
---@field data? any
---@field message? string

---@class ProselintWireDiagnostic
---@field check_path? string
---@field message? string
---@field pos? any
---@field replacements? string
---@field span? any

---@class ProselintFileOutput
---@field diagnostics? ProselintWireDiagnostic[]
---@field error? ProselintWireError

---@class ProselintWireOutput
---@field error? ProselintWireError
---@field result? table<string, ProselintFileOutput>

---@param error_value any
---@param context LintContext
---@param source_key? string
---@return vim.Diagnostic?
local function error_diagnostic(error_value, context, source_key)
  if type(error_value) ~= 'table' then
    return nil
  end

  local message = string_value(error_value.message)

  if message == nil then
    return nil
  end

  return {
    bufnr = context.bufnr,
    code = integer_value(error_value.code),
    col = 0,
    end_col = 0,
    end_lnum = 0,
    lnum = 0,
    message = truncate(compact(message), MAX_MESSAGE_BYTES),
    severity = diagnostic.severity.ERROR,
    source = SOURCE,
    user_data = {
      data = error_value.data,
      source = source_key,
    },
  }
end

---@param item ProselintWireDiagnostic
---@param context LintContext
---@param lines string[]?
---@param source_key string
---@return vim.Diagnostic?
local function finding_diagnostic(item, context, lines, source_key)
  local message = string_value(item.message)

  if message == nil then
    return nil
  end

  local check_path = string_value(item.check_path)
  local lnum, col, end_lnum, end_col = diagnostic_range(lines, item.pos, item.span)
  local replacement = string_value(item.replacements)

  if replacement ~= nil then
    replacement = truncate(replacement, MAX_REPLACEMENT_BYTES)
  end

  return {
    bufnr = context.bufnr,
    code = check_path,
    col = col,
    end_col = end_col,
    end_lnum = end_lnum,
    lnum = lnum,
    message = truncate(compact(message), MAX_MESSAGE_BYTES),
    severity = diagnostic.severity.WARN,
    source = SOURCE,
    user_data = {
      check_path = check_path,
      replacement = replacement,
      source = source_key,
      span = item.span,
    },
  }
end

---@param output string
---@return ProselintWireOutput?
local function decode_output(output)
  local text = vim.trim(output)

  if text == '' then
    return nil
  end

  local ok, decoded = pcall(json.decode, text)

  if not ok or type(decoded) ~= 'table' then
    return nil
  end

  return decoded
end

---@param output string
---@return string?
local function operational_message(output)
  local text = strip_ansi(vim.trim(output))

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch('[^\r\n]+') do
    local line = compact(raw_line)

    if line ~= '' then
      return truncate(line, MAX_MESSAGE_BYTES)
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(output, context)
  local message = operational_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,
      code = 'proselint-output',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = message,
      severity = diagnostic.severity.ERROR,
      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,
      code = 'output-limit',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = string.format('proselint output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),
      severity = diagnostic.severity.WARN,
      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'proselint parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'proselint parser requires context.bufnr')

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local decoded = decode_output(output)

  if decoded == nil then
    return parse_failure(output, context)
  end

  local top_error = error_diagnostic(decoded.error, context)

  if top_error ~= nil then
    return { top_error }
  end

  if type(decoded.result) ~= 'table' then
    return parse_failure(output, context)
  end

  local lines = buffer_lines(context)
  local source_keys = vim.tbl_keys(decoded.result)

  table.sort(source_keys)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for source_index = 1, #source_keys do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local source_key = source_keys[source_index]
    local file_output = decoded.result[source_key]

    if type(file_output) == 'table' then
      local file_error = error_diagnostic(file_output.error, context, source_key)

      if file_error ~= nil then
        diagnostics[#diagnostics + 1] = file_error
      elseif type(file_output.diagnostics) == 'table' then
        for finding_index = 1, #file_output.diagnostics do
          if #diagnostics >= MAX_DIAGNOSTICS then
            break
          end

          local finding = file_output.diagnostics[finding_index]

          if type(finding) == 'table' then
            local item = finding_diagnostic(finding, context, lines, source_key)

            if item ~= nil then
              diagnostics[#diagnostics + 1] = item
            end
          end
        end
      end
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'proselint arguments require LintContext')

  ---@type string[]
  local args = {
    'check',
    '--output-format',
    'json',
  }

  local config = string_value(vim.env.NVIM_PROSELINT_CONFIG)

  if config ~= nil then
    args[#args + 1] = '--config'
    args[#args + 1] = fs.normalize(config)
  end

  return args
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = 'proselint',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'stdout',

  timeout = 60000,
}