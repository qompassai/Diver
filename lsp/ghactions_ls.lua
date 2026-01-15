-- /qompassai/Diver/lsp/ghactions_ls.lua
-- Qompass AI Github Actions LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = {
        workspace = {
            didChangeWorkspaceFolders = {
                dynamicRegistration = true,
            },
        },
    },
    cmd = {
        'gh-actions-language-server',
        '--stdio',
    },
    filetypes = {
        'yaml',
    },
    handlers = {
        ['actions/readFile'] = function(_, result)
            if type(result.path) ~= 'string' then
                return nil, nil
            end
            local file_path = vim.uri_to_fname(result.path)
            if vim.fn.filereadable(file_path) == 1 then
                local f = assert(io.open(file_path, 'r'))
                local text = f:read('*a')
                f:close()
                return text, nil
            end
            return nil, nil
        end,
    },
    init_options = {
        experimentalFeatures = {
            all = true,
        },
    },
    root_markers = {
        '.forgejo/workflows',
        '.gitea/workflows',
        '.github/workflows',
    },
    settings = {},
}