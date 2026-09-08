-- #################################################################
-- /qompassai/lua/scip/index.lua
-- Qompass AI Index
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
-- #################################################################
-- /qompassai/lua/scip/index.lua
-- Qompass AI SCIP Index
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

local api = vim.api

local config = require('scip.config')
local registry = require('scip.registry')
local root = require('scip.root')
local state = require('scip.state')
local ui = require('scip.ui')
local utils = require('scip.utils')

local M = {}

---@class ScipIndexOpts
---@field bufnr? integer Buffer used for indexer detection.
---@field root? string Explicit project root override.

---Validate a generated SCIP index after indexing completes.
---
---This runs only when:
---
---1. `lint_after_index` is enabled.
---2. The `scip` CLI is executable.
---3. The generated index file exists.
---
---@param project_root string Project root containing the generated index.
---@return nil
local function lint_after_index(project_root)
	local cfg = config.get()

	if not cfg.lint_after_index then
		return
	end

	if not utils.executable('scip') then
		ui.notify('SCIP index generated, but the scip CLI is unavailable for validation', vim.log.levels.WARN)
		return
	end

	local index_file = config.index_path(project_root)

	if not utils.path_exists(index_file) then
		ui.notify('Indexer exited successfully but did not create ' .. index_file, vim.log.levels.WARN)
		return
	end

	vim.system({
		'scip',
		'lint',
		index_file,
	}, {
		cwd = project_root,
		text = true,
		timeout = cfg.timeout,
	}, function(result)
		vim.schedule(function()
			if result.code == 0 then
				ui.notify('Index generated and validated: ' .. index_file)
				return
			end

			ui.notify('SCIP index validation failed', vim.log.levels.ERROR)

			ui.show_failure('SCIP lint', result)
		end)
	end)
end

---Resolve the indexer that should be used for an indexing request.
---
---If a name is supplied, that specific indexer is resolved. Otherwise the
---registry auto-detects an indexer from the current buffer and project.
---
---@param name string?
---@param bufnr integer
---@param root_override? string
---@return ScipMatch?, string?
local function resolve_indexer(name, bufnr, root_override)
	if name ~= nil and name ~= '' then
		return registry.resolve(name, bufnr, root_override)
	end

	return registry.detect(bufnr)
end

---Build the complete command line for a resolved SCIP indexer.
---
---The indexer executable becomes argv[1], followed by any static or dynamic
---arguments returned by the indexer configuration.
---
---@param match ScipMatch
---@return string[]?, string?
local function build_command(match)
	local args, resolve_error = utils.resolve_args(match.indexer.args, match.context)

	if args == nil then
		return nil, resolve_error
	end

	local command = {
		match.command,
	}

	vim.list_extend(command, args)

	return command, nil
end

---Generate a SCIP index for the current project.
---
---A named indexer may be supplied explicitly. Otherwise the configured registry
---selects the first enabled indexer matching the current buffer's filetype and
---project markers.
---
---Only one asynchronous indexing process may run at a time.
---
---@param name? string Explicit indexer name.
---@param opts? ScipIndexOpts Optional indexing overrides.
---@return nil
function M.run(name, opts)
	if state.running() then
		ui.notify('A SCIP indexer is already running; use :ScipCancel first', vim.log.levels.WARN)
		return
	end

	opts = opts or {}

	local bufnr = opts.bufnr or api.nvim_get_current_buf()

	local match, resolve_error = resolve_indexer(name, bufnr, opts.root)

	if match == nil then
		ui.notify(resolve_error or 'Unable to resolve a SCIP indexer', vim.log.levels.ERROR)
		return
	end

	local command, command_error = build_command(match)

	if command == nil then
		ui.notify(command_error or 'Unable to build SCIP indexer command', vim.log.levels.ERROR)
		return
	end

	local started_at = vim.uv.hrtime()

	ui.notify(('Indexing %s with %s'):format(match.context.root, match.command))

	---@type vim.SystemObj
	local job

	job = vim.system(command, {
		cwd = match.context.root,
		text = true,
		timeout = config.get().timeout,
	}, function(result)
		vim.schedule(function()
			-- Ignore stale callbacks. This is important if a process
			-- was cancelled and another indexer started afterward.
			if state.current.job ~= job then
				return
			end

			local elapsed = (vim.uv.hrtime() - state.current.started_at) / 1e9

			state.clear()

			if result.code ~= 0 then
				ui.notify(('%s failed after %.1f seconds'):format(match.command, elapsed), vim.log.levels.ERROR)

				ui.show_failure('SCIP: ' .. match.name, result)
				return
			end

			if config.get().lint_after_index then
				lint_after_index(match.context.root)
				return
			end

			ui.notify(('Index generated in %.1f seconds: %s'):format(elapsed, match.context.index_file))
		end)
	end)

	state.start(job, match.name, match.context.root, started_at)
end

---Cancel the currently active SCIP indexing process.
---
---SIGTERM is sent through the native `vim.SystemObj` API. State is cleared
---immediately so another indexing request can begin.
---
---@return nil
function M.cancel()
	local job = state.current.job

	if job == nil then
		ui.notify('No SCIP indexer is running')
		return
	end

	job:kill(15)
	state.clear()

	ui.notify('SCIP indexing cancelled', vim.log.levels.WARN)
end

---Show current SCIP indexer or index-file status.
---
---When an indexer is running, its name, project root, and elapsed runtime are
---reported. Otherwise this reports whether the current project already has an
---index file.
---
---@return nil
function M.status()
	if state.running() then
		ui.notify(
			('%s has been indexing %s for %.1f seconds'):format(
				state.current.indexer or '<unknown>',
				state.current.root or '<unknown>',
				state.elapsed()
			)
		)
		return
	end

	local project_root = root.resolve()
	local index_file = config.index_path(project_root)

	if utils.path_exists(index_file) then
		ui.notify('SCIP index available: ' .. index_file)
		return
	end

	ui.notify('No SCIP index exists at ' .. index_file)
end

---Execute the main `scip` CLI against the current project's index.
---
---This helper is used by lint, print, snapshot, and stats. The caller supplies
---the subcommand-specific arguments while this function handles executable
---validation, project-root discovery, asynchronous execution, and output UI.
---
---@param arguments string[] SCIP CLI arguments after the executable name.
---@param title string Display/quickfix title.
---@param filetype? string Scratch-buffer filetype for successful output.
---@return nil
local function run_scip(arguments, title, filetype)
	if not utils.executable('scip') then
		ui.notify('The scip CLI is not executable', vim.log.levels.ERROR)
		return
	end

	local project_root = root.resolve()
	local index_file = config.index_path(project_root)

	if not utils.path_exists(index_file) then
		ui.notify('No SCIP index exists at ' .. index_file, vim.log.levels.ERROR)
		return
	end

	local command = {
		'scip',
	}

	vim.list_extend(command, arguments)

	vim.system(command, {
		cwd = project_root,
		text = true,
		timeout = config.get().timeout,
	}, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				ui.notify(title .. ' failed', vim.log.levels.ERROR)

				ui.show_failure(title, result)
				return
			end

			ui.show_output(title, utils.system_output(result), filetype)
		end)
	end)
end

---Validate the current project's SCIP index.
---@return nil
function M.lint()
	local project_root = root.resolve()

	run_scip({
		'lint',
		config.index_path(project_root),
	}, 'SCIP lint')
end

---Print the current SCIP index as JSON.
---
---Successful output is opened in a native scratch buffer with `json`
---filetype so syntax highlighting and normal Neovim JSON behavior apply.
---
---@return nil
function M.print()
	local project_root = root.resolve()

	run_scip({
		'print',
		'--json',
		config.index_path(project_root),
	}, 'SCIP index', 'json')
end

---Generate a human-readable snapshot of the current SCIP index.
---
---The snapshot is written below the current project root in `scip-snapshot`.
---
---@return nil
function M.snapshot()
	local project_root = root.resolve()
	local index_file = config.index_path(project_root)
	local destination = vim.fs.joinpath(project_root, 'scip-snapshot')

	run_scip({
		'snapshot',
		'--from',
		index_file,
		'--to',
		destination,
	}, 'SCIP snapshot')
end

---Show statistics for the current SCIP index.
---@return nil
function M.stats()
	local project_root = root.resolve()

	run_scip({
		'stats',
		'--from',
		config.index_path(project_root),
	}, 'SCIP statistics')
end

return M
