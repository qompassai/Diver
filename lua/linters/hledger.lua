
-- ~/.config/nvim/lua/linters/hledger.lua
-- Native hledger check adapter; uses utils/hledger.lua for explicit policy.
-- SPDX-License-Identifier: Apache-2.0
local journal = require('utils.hledger')
---@type Linter
return {
  cmd = journal.config.env_executable,
  args = journal.arguments,
  append_fname = false,
  automatic = journal.config.automatic_lint,
  cwd = journal.cwd,
  env = {}, -- env -i in argv defines the complete child environment.
  exit_codes = { 0, 1 }, -- hledger check returns 1 for data errors.
  ignore_exitcode = false,
  parser = journal.parse,
  root_markers = { '.git' },
  stdin = true,
  stream = 'both',
  timeout = journal.config.timeout_ms,
}