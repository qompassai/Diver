-- /qompassai/Diver/lsp/sq_ls.lua
-- Qompass AI Diver SQL Language Server Config
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
