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
local fn = vim.fn
local M = {}
---@class QompassBspConnection
---@field argv string[]
---@field bspVersion string
---@field languages string[]
---@field name string
---@field version string
---@field path string

---@param path string
---@return table|nil, string|nil
local function decode_connection(path)
	local ok_read, lines = pcall(fn.readfile, path)
	if not ok_read then
		return nil, 'Cannot read ' .. path
	end

	local ok_decode, value = pcall(vim.json.decode, table.concat(lines, '\n'))
	if not ok_decode or type(value) ~= 'table' then
		return nil, 'Invalid BSP JSON in ' .. path
	end

	return value, nil
end

---@param values unknown
---@return boolean
local function is_string_list(values)
	if type(values) ~= 'table' or #values == 0 then
		return false
	end

	for _, value in ipairs(values) do
		if type(value) ~= 'string' or value == '' then
			return false
		end
	end

	return true
end

---@param path string
---@return QompassBspConnection|nil, string|nil
local function validate_connection(path)
	local value, decode_error = decode_connection(path)
	if not value then
		return nil, decode_error
	end
	if type(value.name) ~= 'string' or value.name == '' then
		return nil, 'BSP connection has no valid name: ' .. path
	end
	if not is_string_list(value.argv) then
		return nil, 'BSP connection has no valid argv: ' .. path
	end
	if type(value.bspVersion) ~= 'string' or value.bspVersion == '' then
		return nil, 'BSP connection has no valid bspVersion: ' .. path
	end
	if not is_string_list(value.languages) then
		return nil, 'BSP connection has no valid languages: ' .. path
	end
	if type(value.version) ~= 'string' or value.version == '' then
		value.version = 'unknown'
	end

	---@type QompassBspConnection
	local connection = {
		argv = vim.deepcopy(value.argv),
		bspVersion = value.bspVersion,
		languages = vim.deepcopy(value.languages),
		name = value.name,
		path = path,
		version = value.version,
	}

	return connection, nil
end

---@param bufnr? integer
---@return string|nil
function M.root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root = vim.fs.root(bufnr, {
		'.bsp',
		'Cargo.toml',
	})

	return root and vim.fs.normalize(root) or nil
end

---@param root string
---@param preferred_name? string
---@return QompassBspConnection|nil, string|nil
function M.connection(root, preferred_name)
	local directory = vim.fs.joinpath(root, '.bsp')
	local stat = vim.uv.fs_stat(directory)
	if not stat or stat.type ~= 'directory' then
		return nil, 'No .bsp directory exists at ' .. root
	end

	local paths = vim.fs.find(function(name)
		return name:sub(-5) == '.json'
	end, {
		limit = 1000,
		path = directory,
		type = 'file',
	})
	table.sort(paths)

	local connections = {}
	local errors = {}
	for _, path in ipairs(paths) do
		local connection, connection_error = validate_connection(path)
		if connection then
			connections[#connections + 1] = connection
		elseif connection_error then
			errors[#errors + 1] = connection_error
		end
	end

	if #connections == 0 then
		local detail = #errors > 0 and ': ' .. table.concat(errors, '; ') or ''
		return nil, 'No valid BSP connection file was found in ' .. directory .. detail
	end

	if preferred_name and preferred_name ~= '' then
		for _, connection in ipairs(connections) do
			if connection.name == preferred_name then
				return connection, nil
			end
		end

		return nil, string.format('BSP server %q was not found in %s', preferred_name, directory)
	end

	return connections[1], nil
end

---@param connection QompassBspConnection
---@return boolean, string|nil
function M.executable(connection)
	local command = connection.argv[1]
	if not command or command == '' then
		return false, 'The BSP connection has an empty command'
	end
	if fn.executable(command) ~= 1 then
		return false, 'BSP server is not executable: ' .. command
	end

	return true, nil
end

return M
