-- #################################################################
-- /qompassai/lsp/yara_ls.lua
-- Native YARA-X language server
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
---@source https://github.com/VirusTotal/yara-x/tree/60ad06971467029e77967e59d580cbbe85a1474d
---@source https://virustotal.github.io/yara-x/docs/intro/language-server/

--[[
sudo pacman -S yara

git clone --branch v1.20.0 --depth 1 https://github.com/VirusTotal/yara-x.git
cargo install --locked --path yara-x/ls
--]]

local TOOLING = {
  debounce_text_changes_ms = 150,
  executable = 'yr-ls',
  exit_timeout_ms = 1000,
}
local ROOT_MARKERS = {
  '.git',
  '.hg',
  '.svn',
}
local CODE_FORMATTING = {
  alignMetadata = true,
  alignPatterns = true,
  emptyLineAfterSectionHeader = false,
  emptyLineBeforeSectionHeader = false,
  indentSectionContents = true,
  indentSectionHeaders = true,
  newlineBeforeCurlyBrace = false,
}

local SERVER_OPTIONS = {
  cacheWorkspace = false,
  codeFormatting = CODE_FORMATTING,
  metadataValidation = {},
  ruleNameValidation = '',
}

local function validate_configuration()
  assert(TOOLING.executable == 'yr-ls')
  assert(TOOLING.debounce_text_changes_ms >= 50)
  assert(TOOLING.debounce_text_changes_ms <= 1000)
  assert(TOOLING.exit_timeout_ms >= 100)
  assert(TOOLING.exit_timeout_ms <= 10000)
  assert(#ROOT_MARKERS == 3)
  assert(SERVER_OPTIONS.cacheWorkspace == false)
  assert(#SERVER_OPTIONS.metadataValidation == 0)
  assert(SERVER_OPTIONS.ruleNameValidation == '')
  assert(CODE_FORMATTING.alignMetadata == true)
  assert(CODE_FORMATTING.alignPatterns == true)
  assert(CODE_FORMATTING.indentSectionContents == true)
  assert(CODE_FORMATTING.indentSectionHeaders == true)
  assert(CODE_FORMATTING.newlineBeforeCurlyBrace == false)
  assert(CODE_FORMATTING.emptyLineBeforeSectionHeader == false)
  assert(CODE_FORMATTING.emptyLineAfterSectionHeader == false)
end

validate_configuration()

return ---@type vim.lsp.Config
{
  cmd = {
    TOOLING.executable,
  },
  cmd_env = {
    NO_COLOR = '1',
    RUST_BACKTRACE = '0',
  },
  exit_timeout = TOOLING.exit_timeout_ms,
  filetypes = {
    'yara',
  },
  flags = {
    allow_incremental_sync = false,
    debounce_text_changes = TOOLING.debounce_text_changes_ms,
  },
  init_options = vim.deepcopy(SERVER_OPTIONS),
  name = 'yara_ls',
  root_markers = vim.deepcopy(ROOT_MARKERS),
  settings = {
    YARA = vim.deepcopy(SERVER_OPTIONS),
  },
  single_file_support = true,
  trace = 'off',
  workspace_required = false,
}
