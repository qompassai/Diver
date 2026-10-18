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
            formatting = {
                command = {
                    'alejandra',
                },
            },
            diagnostics = {
                enabled = true,
                ignored = {},
                excludedFiles = {},
            },
            nix = {
                autoArchive = true,
                autoEvalInputs = true,
                binary = 'nix',
                flake = {
                    autoArchive = true,
                    autoEvalInputs = true,
                },
                maxMemoryMB = 2560,
                nixpkgsInputName = 'nixpkgs',
            },
        },
    },
}
