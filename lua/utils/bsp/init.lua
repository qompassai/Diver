-- #################################################################
-- /qompassai/lua/utils/bsp/init.lua
-- Qompass AI Init
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
local M = {}
M.config = {
  cargo = true,
  auto_detect = true,
  cargo_bsp_binary = 'cargo-bsp',
}
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  require('utils.bsp.commands').setup(M.config)
  if M.config.cargo and M.config.auto_detect then
    require('utils.bsp.cargo').setup(M.config)
  end
  return M
end
return M
