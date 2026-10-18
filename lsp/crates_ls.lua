-- /qompassai/lsp/crates_ls.lua
-- Qompass AI Diver Crates LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'crates-lsp',
    },
    filetypes = {
        'toml',
    },
    root_markers = {
        'Cargo.toml',
    },
    init_options = {
        files = {
            'Cargo.toml',
        },
        use_api = false,
        inlay_hints = true,
        up_to_date_hint = '✓',
        needs_update_hint = ' {}',
        diagnostics = true,
        unknown_dep_severity = 2,
        needs_update_severity = 3,
        up_to_date_severity = 4,
    },
}
