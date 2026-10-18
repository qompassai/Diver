-- /qompassai/Diver/lsp/spyglass_ls.lua
-- Qompass AI SpyGlass LSP Spec
-- https://github.com/SpyglassMC/Spyglass/tree/main/packages/language-server
--pnpm add -g  @spyglassmc/language-server
---@type vim.lsp.Config
return {
    cmd = {
        'spyglassmc-language-server',
        '--stdio',
    },
    filetypes = {
        'mcfunction',
    },
    root_markers = {
        'pack.mcmeta',
    },
}
