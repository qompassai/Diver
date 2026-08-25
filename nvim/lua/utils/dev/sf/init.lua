-- #################################################################
-- /qompassai/lua/utils/dev/sf/init.lua
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
function M.setup()
  require('utils.dev.sf.agent')
  require('utils.dev.sf.apex')
  require('utils.dev.sf.auth')
  require('utils.dev.sf.autocmds').setup()
  require('utils.dev.sf.cmdutil')
  require('utils.dev.sf.commands')
  require('utils.dev.sf.community')
  require('utils.dev.sf.data')
  require('utils.dev.sf.files')
  require('utils.dev.sf.flow')
  require('utils.dev.sf.limits')
  require('utils.dev.sf.mappings')
  require('utils.dev.sf.org')
  require('utils.dev.sf.package')
  require('utils.dev.sf.picker')
  require('utils.dev.sf.query')
  require('utils.dev.sf.schema')
  require('utils.dev.sf.tests')
  require('utils.dev.sf.user')
  require('utils.dev.sf.util')
end
return M
