-- /qompassai/Diver/lsp/atlas_ls.lua
-- Qompass AI Atlas LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.filetype.add({
    filename = {
        ['atlas.hcl'] = 'atlas-config',
    },
    pattern = {
        ['.*/*.my.hcl'] = 'atlas-schema-mysql',
        ['.*/*.pg.hcl'] = 'atlas-schema-postgresql',
        ['.*/*.lt.hcl'] = 'atlas-schema-sqlite',
        ['.*/*.ch.hcl'] = 'atlas-schema-clickhouse',
        ['.*/*.ms.hcl'] = 'atlas-schema-mssql',
        ['.*/*.rs.hcl'] = 'atlas-schema-redshift',
        ['.*/*.test.hcl'] = 'atlas-test',
        ['.*/*.plan.hcl'] = 'atlas-plan',
        ['.*/*.rule.hcl'] = 'atlas-rule',
    },
})
vim.treesitter.language.register('hcl', 'atlas-config')
vim.treesitter.language.register('hcl', 'atlas-schema-mysql')
vim.treesitter.language.register('hcl', 'atlas-schema-postgresql')
vim.treesitter.language.register('hcl', 'atlas-schema-sqlite')
vim.treesitter.language.register('hcl', 'atlas-schema-clickhouse')
vim.treesitter.language.register('hcl', 'atlas-schema-mssql')
vim.treesitter.language.register('hcl', 'atlas-schema-redshift')
vim.treesitter.language.register('hcl', 'atlas-test')
vim.treesitter.language.register('hcl', 'atlas-plan')
vim.treesitter.language.register('hcl', 'atlas-rule')
---@type vim.lsp.Config
return {
    cmd = {
        'atlas',
        'tool',
        'lsp',
        '--stdio',
    },
    filetypes = {
        'atlas-*',
    },
    root_markers = {
        'atlas.hcl',
    },
}
