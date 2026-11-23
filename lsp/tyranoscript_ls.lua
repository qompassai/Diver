-- /qompassai/Diver/lsp/tyranoscript_ls.lua
-- Qompass AI Diver TyranoScript LSP Spec
---@source https://github.com/void2610/tyranoscript-lsp
return ---@type vim.lsp.Config
{
    cmd = {
        'node',
        vim.fn.expand(
            '~/.npm-global/tyranoscript-lsp-0.8.4/lib/node_modules/@void2610/tyranoscript-lsp/dist/server.js'
        ),
        '--stdio',
    },
    filetypes = { 'tyranoscript' },
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, function(name, path)
            return name == 'tyrano' and vim.fn.filereadable(vim.fs.joinpath(path, name, 'tyrano.js')) == 1
        end)
        if root then
            on_dir(root)
        end
    end,
    workspace_required = true,
}
