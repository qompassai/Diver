-- /qompassai/Diver/lsp/arduino_ls.lua
-- Qompass AI Arduino LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'arduino-language-server',
    },
    filetypes = {
        'arduino',
    },
    root_markers = {
        '*.ino',
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.semanticTokensProvider = nil
        vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end,
}
