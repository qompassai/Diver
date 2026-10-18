-- /qompassai/Diver/lsp/nixd_ls.lua
-- Qompass AI Nixd LSP Config
return ---@type vim.lsp.Config
{
    cmd = {
        'nixd',
        '--log=info',
        '--inlay-hints=true',
        '--semantic-tokens=true',
        '--pretty',
    },
    filetypes = {
        'nix',
    },
    root_markers = {
        'flake.nix',
        'default.nix',
        '.git',
    },
    settings = {
        nixd = {
            diagnostic = {
                suppress = {
                    'sema-extra-with',
                },
            },
            nixpkgs = {
                expr = 'import <nixpkgs> { }',
            },
            formatting = {
                command = {
                    'nixfmt',
                },
            },
            options = {
                home_manager = {
                    expr = '(builtins.getFlake ("git+file://" + toString ./.)).homeConfigurations."ruixi@k-on".options',
                },
                ['flake-parts'] = {},
                nixos = {
                    expr = '(builtins.getFlake ("git+file://" + toString ./.)).nixosConfigurations.k-on.options',
                },
            },
        },
    },
}
