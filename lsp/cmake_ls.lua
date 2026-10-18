-- /qompassai/Diver/lsp/cmake_ls.lua
-- Qompass AI CMake LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'cmake-language-server',
    },
    filetypes = {
        'cmake',
    },
    root_markers = {
        'build',
        'cmake',
        'CMakePresets.json',
        'CTestConfig.cmake',
        '.git',
    },
    init_options = {
        buildDirectory = 'build',
    },
}
