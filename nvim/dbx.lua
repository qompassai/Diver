-- #################################################################
-- /qompassai/diver/dbx.lua
-- Qompass AI Diver Database Config
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
	{
		name = {
			'MySQL Local',
		},
		kind = 'sqlite',
		lsp = true,
		url = {
			'mysql://root:password@localhost:3306/',
		},
	},
	{
		name = {
			'MySQL Production',
		},
		url = 'mysql://user:password@production-server:3306/database',
	},
	{
		name = {
			'SQLite Main',
		},
		url = 'sqlite:~/databases/main.sqlite',
	},
	{
		name = {
			'QMail',
		},
		url = {
			'sqlite:./db/development.sqlite3',
		},
	},
	{
		name = {
			'Project DB',
		},
		url = 'sqlite:./db/development.sqlite3',
	},
	{
		name = {
			'Zotero',
		},
		url = {
			'sqlite:~/.local/share/zotero/zotero.sqlite',
		},
	},
	{
		name = 'PostgreSQL Local',
		url = 'postgresql://postgres:password@localhost:5432/postgres',
	},
	{
		name = 'PostgreSQL Production',
		url = 'postgresql://user:password@production-server:5432/database',
	},
}
