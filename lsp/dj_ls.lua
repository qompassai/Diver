-- /qompassai/Diver/lsp/dj_ls.lua
-- Qompass AI Django LSP Spec
-- uv tool install django-language-server
return ---@type vim.lsp.Config
{
    cmd = {
        'djls',
        'serve',
    },
    filetypes = {
        'htmldjango',
        -- 'python',
    },
    root_markers = {
        'manage.py',
        'pyproject.toml',
        '.git',
    },
}
