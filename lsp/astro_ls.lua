-- /qompassai/Diver/lsp/astro.lua
-- Qompass AI Astro-ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@param root_dir string
---@return string|nil
local function get_typescript_server_path(root_dir)
    local candidates = {
        root_dir .. '/node_modules/typescript/lib',
        root_dir .. '/packages/typescript/lib',
    }
    for _, p in ipairs(candidates) do
        if vim.uv.fs_stat(p) then
            return p
        end
    end
    local function try(cmd)
        local res = vim.system(cmd, {
            text = true,
        }):wait()
        if res.code == 0 then
            local dir = res.stdout:gsub('%s+$', '')
            local lib = dir .. '/node_modules/typescript/lib'
            if vim.uv.fs_stat(lib) then
                return lib
            end
        end
    end
    return try({ 'npm', 'root', '-g' }) or try({ 'pnpm', 'root', '-g' }) or try({ 'yarn', 'global', 'dir' })
end
---@type vim.lsp.Config
return {
    cmd = {
        'astro-ls',
        '--stdio',
    },
    filetypes = {
        'astro',
    },
    root_markers = {
        '.git',
        'package.json',
        'tsconfig.json',
        'jsconfig.json',
    },
    init_options = {
        typescript = {},
    },
    ---@param params table
    before_init = function(params, config) ---@param config table
        local root_dir = config.root_dir or (params.rootUri and vim.uri_to_fname(params.rootUri)) or vim.fn.getcwd()
        local ts_opts = config.init_options.typescript or {} ---@type { tsdk?: string }
        if not ts_opts.tsdk then
            local tsdk = get_typescript_server_path(root_dir)
            if tsdk then
                ts_opts.tsdk = tsdk
            else
                ts_opts.tsdk = vim.fn.expand('$HOME/.local/share/pnpm/global/5/node_modules/typescript/lib')
            end
        end
        config.init_options.typescript = ts_opts
    end,
}
