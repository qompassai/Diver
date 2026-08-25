-- /qompassai/Diver/lsp/larkparse_ls
-- Qompass AI Diver LarkParse LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'python',
        '-m',
        'lark_parser_language_server',
    },
    filetypes = {
        'lark',
    },
    root_markers = {
        '.git',
    },
}
