
-- #################################################################
-- /qompassai/Diver/lsp/sq_ls.lua
-- Qompass AI Diver SQL Language Server Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/joe-re/sql-language-server
---@source https://docs.sqlfluff.com/en/stable/

---@type vim.lsp.Config
return {
    cmd = {
        'sql-language-server',
        'up',
        '--method',
        'stdio',
    },

    filetypes = {
        'mysql',
        'pgsql',
        'sql',
    },

    root_markers = {
        '.sqllsrc.json',

        {
            '.sqlfluff',
            'pyproject.toml',
            'dbt_project.yml',
        },

        '.git',
    },

    settings = {
        sqlLanguageServer = {
            lint = {
                rules = {
                    ['align-column-to-the-first'] = 'off',

                    ['align-where-clause-to-the-first'] = 'off',

                    ['column-new-line'] = 'off',

                    ['linebreak-after-clause-keyword'] = 'off',

                    ['reserved-word-case'] = 'off',

                    ['space-surrounding-operators'] = 'off',

                    ['where-clause-new-line'] = 'off',
                },
            },
        },
    },
}