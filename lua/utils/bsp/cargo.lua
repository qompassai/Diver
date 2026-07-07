-- #################################################################
-- /qompassai/lua/utils/bsp/cargo.lua
-- Qompass AI Cargo
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

local function has_cargo_bsp(bin)
  return vim.fn.executable(bin or 'cargo-bsp') == 1
end
local function is_cargo_project(root)
  return root and vim.fn.filereadable(root .. '/Cargo.toml') == 1
end
function M.setup(config)
  local root = vim.fs.root(0, { 'Cargo.toml', '.bsp' })
  if not root or not is_cargo_project(root) then
    return
  end
  if not has_cargo_bsp(config.cargo_bsp_binary) then
    vim.notify('[BSP] cargo-bsp not found in PATH', vim.log.levels.WARN)
    return
  end

  return true
end

return M
