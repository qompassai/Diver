-- /qompassai/Diver/lsp/vale_ls.lua
-- Qompass AI Vale LSP Spec
---@source https://vale.sh/docs/guides/lsp
return ---@type vim.lsp.Config
{
        cmd = {
                'vale-ls',
        },
        filetypes = {
                'asciidoc',
                --  'markdown',
                'text',
                'tex',
                'rst',
                'html',
                'xml',
        },
        root_markers = {
                '.vale.ini',
                '_vale.ini',
        },
        settings = {
                ['vale-ls'] = {
                        initializationOptions = {
                                installVale = true,
                                filter = nil,
                                configPath = vim.env.VALE_CONFIG_PATH
                                    or vim.fs.joinpath(vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config'), 'vale',
                                            '.vale.ini'),
                                syncOnStartup = true,
                        },
                },
        },
}
