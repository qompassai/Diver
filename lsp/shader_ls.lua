-- /qompassai/Diver/lsp/shader_ls.lua
-- Qompass AI Shader LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'shader-ls',
        '--stdio',
    },
    filetypes = {
        'shaderlab',
        'hlsl',
        'cg',
    },
    root_markers = {
        'Packages',
        'ProjectSettings',
        '.git',
    },
    settings = {
        ['ShaderLab.CompletionWord'] = true,
    },
    on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
    end,
}
