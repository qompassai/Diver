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
local fs = vim.fs
local levels = vim.log.levels
local lsp = vim.lsp

local core_lsp =
  require('config.core.lsp')

local ERROR =
  diagnostic.severity.ERROR

local FISH_LINT_DIAGNOSTICS_MAX = 1024
local FISH_LINT_MESSAGE_LENGTH_MAX = 16 * 1024
local FISH_LINT_OUTPUT_LENGTH_MAX = 4 * 1024 * 1024

local FISH_LINT_CODE = 'syntax'
local FISH_LINT_SOURCE = 'fish'

local fish_lint_namespace =
  api.nvim_create_namespace(
    'QompassFishSyntax'
  )

---@type table<integer, vim.SystemObj>
local fish_lint_jobs = {}

---@type table<integer, integer>
local fish_lint_generations = {}

---@param value string
---@return string
local function trim(value)
  return (
    value:gsub(
      '^%s*(.-)%s*$',
      '%1'
    )
  )
end

---@param value string
---@return string
local function strip_ansi(value)
  return (
    value:gsub(
      '\27%[[%d;?]*[ -/]*[@-~]',
      ''
    )
  )
end

---@param value string
---@return string
local function normalize_message(value)
  value =
    strip_ansi(value)

  value =
    value:gsub(
      '\r\n',
      '\n'
    )

  value =
    value:gsub(
      '\r',
      '\n'
    )

  value =
    trim(value)

  if #value > FISH_LINT_MESSAGE_LENGTH_MAX then
    value =
      value:sub(
        1,
        FISH_LINT_MESSAGE_LENGTH_MAX
      )
      .. '\n[message truncated]'
  end

  return value
end

---@param bufnr integer
local function clear_fish_lint(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  diagnostic.reset(
    fish_lint_namespace,
    bufnr
  )
end

---@param bufnr integer
---@param line integer
---@param message string
---@return vim.Diagnostic
local function make_fish_diagnostic(
  bufnr,
  line,
  message
)
  local lnum =
    math.max(
      line - 1,
      0
    )

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
local function parse_fish_lint(
  output,
  bufnr
)
  if output == '' then
    return {}
  end

  if #output > FISH_LINT_OUTPUT_LENGTH_MAX then
    output =
      output:sub(
        1,
        FISH_LINT_OUTPUT_LENGTH_MAX
      )
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for raw_line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= FISH_LINT_DIAGNOSTICS_MAX then
      break
    end

    local line =
      strip_ansi(raw_line)

    --
    -- Syntax checking from stdin normally uses:
    --
    --   Standard input (line 12): ...
    --
    -- File-based parser errors use the same "(line N):" shape.
    --
    local line_text,
      message =
        line:match(
          '^.-%(line%s+(%d+)%)%:%s*(.+)$'
        )

    if
      line_text ~= nil
      and message ~= nil
    then
      local line_number =
        tonumber(line_text)

      if line_number ~= nil then
        line_number =
          math.floor(line_number)

        message =
          normalize_message(message)

        if
          line_number >= 1
          and message ~= ''
        then
          diagnostics[#diagnostics + 1] =
            make_fish_diagnostic(
              bufnr,
              line_number,
              message
            )
        end
      end
    end
  end

  return diagnostics
end

---@param bufnr integer
---@return string?
local function buffer_text(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local lines =
    api.nvim_buf_get_lines(
      bufnr,
      0,
      -1,
      false
    )

  --
  -- Preserve the normal final newline expected by shell scripts.
  --
  return table.concat(
    lines,
    '\n'
  ) .. '\n'
end

---@param bufnr integer
local function stop_fish_lint(bufnr)
  local job =
    fish_lint_jobs[bufnr]

  if job == nil then
    return
  end

  fish_lint_jobs[bufnr] =
    nil

  pcall(
    job.kill,
    job,
    15
  )
end

---@param bufnr integer
local function run_fish_lint(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.bo[bufnr].filetype ~= 'fish' then
    return
  end

  local text =
    buffer_text(bufnr)

  if text == nil then
    return
  end

  stop_fish_lint(bufnr)

  local generation =
    (fish_lint_generations[bufnr] or 0)
    + 1

  fish_lint_generations[bufnr] =
    generation

  local job =
    vim.system(
      {
        'fish',
        '--no-execute',
      },
      {
        stdin = text,
        text = true,
      },
      function(result)
        vim.schedule(
          function()
            if
              not api.nvim_buf_is_valid(bufnr)
              or fish_lint_generations[bufnr]
                ~= generation
            then
              return
            end

            fish_lint_jobs[bufnr] =
              nil

            local stderr =
              result.stderr or ''

            local diagnostics =
              parse_fish_lint(
                stderr,
                bufnr
              )

            diagnostic.set(
              fish_lint_namespace,
              bufnr,
              diagnostics,
              {
                severity_sort = true,
                underline = true,
                update_in_insert = false,
                virtual_text = true,
              }
            )
          end
        )
      end
    )

  fish_lint_jobs[bufnr] =
    job
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  core_lsp.on_attach(
    client,
    bufnr
  )

  local group =
    api.nvim_create_augroup(
      'QompassFishLsp'
        .. bufnr,
      {
        clear = true,
      }
    )

  --
  -- Native Fish parser verification.
  --
  -- fish-lsp remains the continuous semantic diagnostic engine.
  -- `fish --no-execute` runs only at stable checkpoints.
  --
  api.nvim_create_autocmd(
    'BufWritePost',
    {
      buffer = bufnr,
      group = group,

      callback = function()
        run_fish_lint(
          bufnr
        )
      end,

      desc =
        'Run native Fish syntax validation',
    }
  )

  api.nvim_create_autocmd(
    {
      'BufDelete',
      'BufWipeout',
    },
    {
      buffer = bufnr,
      group = group,

      callback = function()
        stop_fish_lint(
          bufnr
        )

        fish_lint_generations[bufnr] =
          nil

        clear_fish_lint(
          bufnr
        )
      end,

      desc =
        'Clean Fish syntax linter state',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'FishLint',
    function()
      run_fish_lint(
        bufnr
      )
    end,
    {
      desc =
        'Run native fish --no-execute syntax check',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'FishLintClear',
    function()
      clear_fish_lint(
        bufnr
      )
    end,
    {
      desc =
        'Clear native Fish syntax diagnostics',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'FishLspRestart',
    function()
      client:stop(true)

      vim.schedule(
        function()
          lsp.enable(
            'fish_ls',
            true
          )
        end
      )
    end,
    {
      desc =
        'Restart fish-lsp',
    }
  )

  api.nvim_buf_create_user_command(
    bufnr,
    'FishLspSettings',
    function()
      vim.notify(
        vim.inspect(
          client.config.settings
        ),
        levels.INFO
      )
    end,
    {
      desc =
        'Show fish-lsp settings',
    }
  )

  --
  -- Perform one authoritative parser pass as soon as fish-lsp attaches.
  --
  vim.schedule(
    function()
      run_fish_lint(
        bufnr
      )
    end
  )
end

return ---@type vim.lsp.Config
{
  capabilities =
    core_lsp.capabilities,

  cmd = {
    'fish-lsp',
    'start',
  },

  filetypes = {
    'fish',
  },

  on_attach =
    on_attach,

  root_markers = {
    '.git',
    'config.fish',
  },

  settings = {
    fish_lsp = {
      --
      -- Paths indexed in addition to the active workspace.
      --
      fish_lsp_all_indexed_paths = {
        '$__fish_config_dir',
        '$__fish_data_dir',
        '$__fish_user_data_dir',
        '$fish_function_path',
      },

      --
      -- Wrapper functions such as aliases and exports are valid Fish idioms.
      --
      fish_lsp_allow_fish_wrapper_functions =
        true,

      fish_lsp_commit_characters = {
        '\t',
        ' ',
        ';',
      },

      --
      -- Tiger policy:
      --
      -- Begin with zero globally disabled diagnostics. Suppress only confirmed
      -- project-specific false positives.
      --
      fish_lsp_diagnostic_disable_error_codes = {},

      --
      -- Keep all implemented handlers available.
      --
      fish_lsp_disabled_handlers = {},

      fish_lsp_enable_experimental_diagnostics =
        true,

      --
      -- Empty means do not restrict the normal handler set.
      --
      fish_lsp_enabled_handlers = {},

      fish_lsp_fish_path =
        'fish',

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

      --
      -- Leave empty during normal operation. Set a concrete path only when
      -- debugging fish-lsp itself.
      --
      fish_lsp_log_file = '',

      fish_lsp_log_level =
        'info',

      --
      -- Generous indexing ceiling for large Fish configuration trees.
      --
      fish_lsp_max_background_files =
        10000,

      --
      -- Zero means no artificial diagnostic count cap.
      --
      fish_lsp_max_diagnostics =
        0,

      fish_lsp_max_workspace_depth =
        8,

      --
      -- Paths fish-lsp may offer modifications/code actions for.
      --
      fish_lsp_modifiable_paths = {
        '$__fish_config_dir',
        '$__fish_user_data_dir',
      },

      --
      -- Tiger preference: explicit Fish builtins reduce ambiguity where an
      -- external command and builtin share a name.
      --
      fish_lsp_prefer_builtin_fish_commands =
        true,

      --
      -- Autoloaded functions should explain their purpose.
      --
      fish_lsp_require_autoloaded_functions_to_have_description =
        true,

      --
      -- Keep UI responsibility inside Neovim rather than server popups.
      --
      fish_lsp_show_client_popups =
        false,

      --
      -- v1.1.4 changed this behavior to default true. Explicitly keep it true
      -- so each Fish file/workspace remains correctly scoped.
      --
      fish_lsp_single_workspace_support =
        true,

      --
      -- Enable the stricter conditional-command diagnostic mode introduced as
      -- an opt-in setting.
      --
      fish_lsp_strict_conditional_command_warnings =
        true,

      --
      -- v1.1.4 supports overriding the embedded Tree-sitter Fish WASM.
      -- Empty means use fish-lsp's bundled grammar.
      --
      fish_lsp_tree_sitter_wasm_path =
        '',
    },
  },
}