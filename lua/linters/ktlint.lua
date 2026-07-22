-- #################################################################
-- /qompassai/lua/linters/ktlint.lua
-- Qompass AI Ktlint
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
return {
	name = 'ktlint',
	cmd = 'ktlint',
	stdin = true,
	append_fname = false,
	args = function(context)
		return {
			'--stdin',
			'--stdin-path',
			context.filename,
			'--reporter=plain',
			'--log-level=none',
		}
	end,
	stream = 'stderr',
	ignore_exitcode = true,
	errorformat = {
		'%f:%l:%c: %m',
		'%-G%.%#',
	},
} --[[@as vim.lint.Config]]
