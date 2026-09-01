-- #################################################################
-- /qompassai/Diver/lsp/fish_ls.lua
-- Qompass AI Diver Fish LSP + Native Syntax Linter Config
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/ndonfris/fish-lsp
---@source https://fishshell.com/docs/current/cmds/fish.html

local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local levels = vim.log.levels
local lsp = vim.lsp

local ERROR = diagnostic.severity.ERROR

local FISH_LINT_CODE = 'syntax'

local FISH_LINT_DIAGNOSTICS_MAX = 1024

local FISH_LINT_MESSAGE_LENGTH_MAX = 16 * 1024

local FISH_LINT_OUTPUT_LENGTH_MAX = 4 * 1024 * 1024

local FISH_LINT_SOURCE = 'fish'

local fish_lint_namespace = api.nvim_create_namespace('FishSyntax')

---@type table<integer, integer>
local fish_lint_generations = {}

---@type table<integer, vim.SystemObj>
local fish_lint_jobs = {}

---@type table<integer, true>
local attached_buffers = {}

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function strip_ansi(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string', 'value must be a string')

  value = strip_ansi(value)

  value = value:gsub('\r\n', '\n')

  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > FISH_LINT_MESSAGE_LENGTH_MAX then
    value = value:sub(1, FISH_LINT_MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@return boolean
local function fish_available()
  return fn.executable('fish') == 1
end

---@param bufnr integer
---@return boolean
local function valid_fish_buffer(bufnr)
  return api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'fish'
end

---@param bufnr integer
local function clear_fish_lint(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  diagnostic.reset(fish_lint_namespace, bufnr)
end

---@param bufnr integer
---@param line integer
---@param message string
---@return vim.Diagnostic
local function make_fish_diagnostic(bufnr, line, message)
  assert(bufnr >= 0, 'bufnr must be non-negative')

  assert(line >= 1, 'line must be one-based')

  assert(message ~= '', 'message must not be empty')

  local lnum = math.max(line - 1, 0)

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = lnum,

    col = 0,
    end_col = 1,

    message = message,

    severity = ERROR,

    source = FISH_LINT_SOURCE,

    code = FISH_LINT_CODE,

    user_data = {
      checker = 'fish --no-execute',
    },
  }
end

---@param output string
---@param bufnr integer
---@return vim.Diagnostic[]
local function parse_fish_lint(output, bufnr)
  assert(type(output) == 'string', 'output must be a string')

  if output == '' then
    return {}
  end

  if #output > FISH_LINT_OUTPUT_LENGTH_MAX then
    output = output:sub(1, FISH_LINT_OUTPUT_LENGTH_MAX)
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for raw_line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= FISH_LINT_DIAGNOSTICS_MAX then
      break
    end

    local line = strip_ansi(raw_line)

    local line_text, message = line:match('^.-%(line%s+(%d+)%)%:%s*(.+)$')

    if line_text ~= nil and message ~= nil then
      local line_number = tonumber(line_text)

      if line_number ~= nil then
        line_number = math.floor(line_number)

        message = normalize_message(message)

        if line_number >= 1 and message ~= '' then
          diagnostics[#diagnostics + 1] = make_fish_diagnostic(bufnr, line_number, message)
        end
      end
    end
  end

  return diagnostics
end

---@param bufnr integer
---@return string?
local function buffer_text(bufnr)
  if not valid_fish_buffer(bufnr) then
    return nil
  end

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  return table.concat(lines, '\n') .. '\n'
end

---@param bufnr integer
local function stop_fish_lint(bufnr)
  local job = fish_lint_jobs[bufnr]

  if job == nil then
    return
  end

  fish_lint_jobs[bufnr] = nil

  pcall(job.kill, job, 15)
end

---@param bufnr integer
local function run_fish_lint(bufnr)
  if not valid_fish_buffer(bufnr) then
    return
  end

  if not fish_available() then
    diagnostic.set(fish_lint_namespace, bufnr, {}, {})

    return
  end

  local text = buffer_text(bufnr)

  if text == nil then
    return
  end

  stop_fish_lint(bufnr)

  local generation = (fish_lint_generations[bufnr] or 0) + 1

  fish_lint_generations[bufnr] = generation

  local job = vim.system({
    'fish',
    '--no-execute',
  }, {
    stdin = text,
    text = true,
  }, function(result)
    vim.schedule(function()
      if not api.nvim_buf_is_valid(bufnr) or fish_lint_generations[bufnr] ~= generation then
        return
      end

      fish_lint_jobs[bufnr] = nil

      local stderr = result.stderr or ''

      local diagnostics = parse_fish_lint(stderr, bufnr)

      diagnostic.set(fish_lint_namespace, bufnr, diagnostics, {
        severity_sort = true,

        underline = true,

        update_in_insert = false,

        virtual_text = true,
      })
    end)
  end)

  fish_lint_jobs[bufnr] = job
end

---@param bufnr integer
local function cleanup_buffer(bufnr)
  stop_fish_lint(bufnr)

  fish_lint_generations[bufnr] = nil

  attached_buffers[bufnr] = nil

  clear_fish_lint(bufnr)
end

---@param bufnr integer
---@param name string
---@param callback function
---@param desc string
local function create_buffer_command(bufnr, name, callback, desc)
  api.nvim_buf_create_user_command(bufnr, name, callback, {
    desc = desc,
    force = true,
  })
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  if not valid_fish_buffer(bufnr) then
    return
  end

  if attached_buffers[bufnr] then
    return
  end

  attached_buffers[bufnr] = true

  local group = api.nvim_create_augroup('FishLsp' .. bufnr, {
    clear = true,
  })

  api.nvim_create_autocmd('BufWritePost', {
    buffer = bufnr,
    group = group,

    callback = function()
      run_fish_lint(bufnr)
    end,

    desc = 'Run native Fish syntax validation',
  })

  api.nvim_create_autocmd({
    'BufDelete',
    'BufWipeout',
  }, {
    buffer = bufnr,
    group = group,

    callback = function()
      cleanup_buffer(bufnr)
    end,

    desc = 'Clean Fish syntax linter state',
  })

  create_buffer_command(bufnr, 'FishLint', function()
    run_fish_lint(bufnr)
  end, 'Run native fish --no-execute syntax check')

  create_buffer_command(bufnr, 'FishLintClear', function()
    clear_fish_lint(bufnr)
  end, 'Clear native Fish syntax diagnostics')

  create_buffer_command(bufnr, 'FishLspRestart', function()
    local client_id = client.id

    client:stop(true)

    attached_buffers[bufnr] = nil

    vim.schedule(function()
      lsp.enable('fish_ls', false)

      lsp.enable('fish_ls', true)

      vim.notify(string.format('Restarted fish-lsp client %d', client_id), levels.INFO)
    end)
  end, 'Restart fish-lsp')

  create_buffer_command(bufnr, 'FishLspSettings', function()
    vim.notify(vim.inspect(client.config.settings), levels.INFO)
  end, 'Show fish-lsp settings')

  vim.schedule(function()
    if valid_fish_buffer(bufnr) then
      run_fish_lint(bufnr)
    end
  end)
end

return ---@type vim.lsp.Config
{
  cmd = {
    'fish-lsp',
    'start',
  },

  filetypes = {
    'fish',
  },

  on_attach = on_attach,

  root_markers = {
    'config.fish',
    '.git',
  },

  settings = {
    fish_lsp = {
      fish_lsp_all_indexed_paths = {
        '$__fish_config_dir',
        '$__fish_data_dir',
        '$__fish_user_data_dir',
        '$fish_function_path',
      },

      fish_lsp_allow_fish_wrapper_functions = true,

      fish_lsp_commit_characters = {
        '\t',
        ' ',
        ';',
      },

      fish_lsp_diagnostic_disable_error_codes = {},

      fish_lsp_disabled_handlers = {},

      fish_lsp_enable_experimental_diagnostics = true,

      fish_lsp_enabled_handlers = {},

      fish_lsp_fish_path = 'fish',

      fish_lsp_ignore_paths = {
        '**/.cache/**',
        '**/.direnv/**',
        '**/.git/**',
        '**/.hg/**',
        '**/.idea/**',
        '**/.mypy_cache/**',
        '**/.pytest_cache/**',
        '**/.ruff_cache/**',
        '**/.svn/**',
        '**/.tox/**',
        '**/.venv/**',
        '**/.vscode/**',
        '**/__pycache__/**',
        '**/build/**',
        '**/containerized/**',
        '**/coverage/**',
        '**/dist/**',
        '**/docker/**',
        '**/node_modules/**',
        '**/result/**',
        '**/target/**',
        '**/vendor/**',
      },

      fish_lsp_log_file = '',

      fish_lsp_log_level = 'info',

      fish_lsp_max_background_files = 10000,

      fish_lsp_max_diagnostics = 0,

      fish_lsp_max_workspace_depth = 8,

      fish_lsp_modifiable_paths = {
        '$__fish_config_dir',
        '$__fish_user_data_dir',
      },

      fish_lsp_prefer_builtin_fish_commands = true,

      fish_lsp_require_autoloaded_functions_to_have_description = true,

      fish_lsp_show_client_popups = false,

      fish_lsp_single_workspace_support = true,

      fish_lsp_strict_conditional_command_warnings = true,

      fish_lsp_tree_sitter_wasm_path = '',
    },
  },
}