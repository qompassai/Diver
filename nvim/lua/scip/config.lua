-- #################################################################
-- /qompassai/lua/scip/config.lua
-- Qompass AI Config
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
local fs = vim.fs
local M = {}
---@class ScipContext
---@field bufnr integer Buffer being indexed.
---@field filename string Current source filename.
---@field index_file string Resolved SCIP index path.
---@field name string Indexer name.
---@field root string Resolved project root.

---@class ScipIndexer
---@field args string[]|fun(context: ScipContext): string[]
---@field command string|fun(context: ScipContext): string
---@field enabled? boolean
---@field filetypes table<string, boolean>
---@field markers string[]

---@class ScipConfig
---@field index_file string
---@field indexer_order string[]
---@field indexers table<string, ScipIndexer>
---@field lint_after_index boolean
---@field notify boolean
---@field root_markers string[]
---@field timeout integer

---@class ScipConfigOpts
---@field index_file? string
---@field indexer_order? string[]
---@field indexers? table<string, ScipIndexer>
---@field lint_after_index? boolean
---@field notify? boolean
---@field root_markers? string[]
---@field timeout? integer

---Load the built-in SCIP indexers.
---
---Each language-specific indexer is isolated under `scip/indexers/` so this
---module remains responsible only for global SCIP configuration.
---
---@return table<string, ScipIndexer>
local function default_indexers()
	return {
		clang = require('scip.indexers.clang'),
		dart = require('scip.indexers.dart'),
		dotnet = require('scip.indexers.dotnet'),
		go = require('scip.indexers.go'),
		java = require('scip.indexers.java'),
		latex = require('scip.indexers.latex'),
		lua = require('scip.indexers.lua'),
		nix = require('scip.indexers.nix'),
		php = require('scip.indexers.php'),
		python = require('scip.indexers.python'),
		ruby = require('scip.indexers.ruby'),
		rust = require('scip.indexers.rust'),
		typescript = require('scip.indexers.typescript'),
		zig = require('scip.indexers.zig'),
	}
end

---@type ScipConfig
local defaults = {
	index_file = 'index.scip',
	indexer_order = {
		'clang',
		'dart',
		'dotnet',
		'go',
		'java',
		'latex',
		'lua',
		'nix',
		'php',
		'python',
		'ruby',
		'rust',
		'typescript',
		'zig',
	},

	indexers = default_indexers(),

	lint_after_index = true,

	notify = true,

	root_markers = {
		'.git',
		'.hg',
	},

	timeout = 300000,
}

---@type ScipConfig
M.values = vim.deepcopy(defaults)

---Return the currently active SCIP configuration.
---@return ScipConfig
function M.get()
	return M.values
end

---Resolve the configured SCIP index path for a project.
---
---Absolute paths are preserved. Relative paths are resolved underneath the
---provided project root.
---
---@param root string Project root.
---@return string index_path Resolved SCIP index path.
function M.index_path(root)
	local configured = M.values.index_file

	if configured:sub(1, 1) == '/' then
		return fs.normalize(configured)
	end

	return fs.joinpath(root, configured)
end

---Reset the active configuration to the built-in defaults.
---
---The indexer modules are reloaded from their cached Lua module values through
---`default_indexers()` so the returned configuration is independent from any
---runtime mutations made to `M.values`.
---@return nil
function M.reset()
	defaults.indexers = default_indexers()

	M.values = vim.deepcopy(defaults)
end

---Apply user configuration on top of the built-in defaults.
---
---`vim.tbl_deep_extend()` allows individual indexer settings to be overridden
---without replacing the entire default configuration.
---
---@param opts? ScipConfigOpts User SCIP configuration.
---@return nil
function M.setup(opts)
	opts = opts or {}

	defaults.indexers = default_indexers()

	M.values = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)

	table.sort(M.values.indexer_order)
end

return M
