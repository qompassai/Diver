-- #################################################################
-- /qompassai/lsp/crates_ls.lua
-- Qompass AI Diver Crates LSP Spec
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
return ---@type vim.lsp.Config
{
  cmd = {
    'crates-lsp',
  },
  filetypes = {
    'toml',
  },
  root_markers = {
    'Cargo.toml',
  },
  init_options = {
    files = {
      'Cargo.toml',
    },
    use_api = false,
    inlay_hints = true,
    up_to_date_hint = '✓',
    needs_update_hint = ' {}',
    diagnostics = true,
    unknown_dep_severity = 2,
    needs_update_severity = 3,
    up_to_date_severity = 4,
  },
}
