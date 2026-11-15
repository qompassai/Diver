-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
return ---@type vim.lsp.Config
{
    cmd = {
        'nil',
        '--stdio',
    },
    filetypes = {
        'nix',
    },
    root_markers = {
        'default.nix',
        'flake.nix',
        '.git',
    },
    settings = {
        ['nil'] = {
            diagnostics = {
                excludedFiles = {},
                ignored = {},
            },
            formatting = {
                command = {
                    'alejandra',
                },
            },
            nix = {
                binary = 'nix',
                flake = {
                    autoArchive = true,
                    autoEvalInputs = true,
                    nixpkgsInputName = 'nixpkgs',
                },
                maxMemoryMB = 2560,
            },
        },
    },
}
