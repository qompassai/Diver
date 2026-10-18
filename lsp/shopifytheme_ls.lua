-- /qompassai/Diver/lsp/shopifytheme_ls.lua
-- Qompass AI Shopify Theme LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'shopify',
        'theme',
        'language-server',
    },
    filetypes = {
        'liquid',
    },
    root_markers = {
        '.shopifyignore',
        '.theme-check.yml',
        '.theme-check.yaml',
        'shopify.theme.toml',
    },
    settings = {},
}
