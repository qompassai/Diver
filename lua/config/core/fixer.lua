-- /qompassai/Diver/lua/config/core/fixer.lua
-- Qompass AI Diver Fixer Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@class M
---@type table<string, string[]>
M.fixers_by_ft = {
    ['_'] = {
        'trim_whitespace',
    },
    astro = {
        'biome',
    },
    awk = {
        'gawk',
    },
    bash = {
        'shfmt',
        'shellcheck',
        'bashate',
    },
    clojure = {
        'cljfmt',
    },
    css = {
        'biome',
        'prettierd',
        'css-beautify',
    },
    ejs = {
        'biome',
    },
    gleam = {
        'gleam_format',
    },
    go = {
        'goimports',
        'gofumpt',
        'golines',
    },
    haskell = {
        'brittany',
        'ormolu',
        'fourmolu',
    },
    helm = {
        'helm_format',
    },
    html = {
        'prettierd',
        'tidy',
        'html-beautify',
    },
    htmlangular = {
        'biome',
        'djlint',
    },
    htmldjango = {
        'biome',
        'djlint',
    },
    http = {
        'kulala_fmt',
    },
    java = {
        'google-java-format',
    },
    javascript = {
        'biome',
    },
    javascriptreact = {
        'biome',
        'prettierd',
    },
    json = {
        'jq',
        'fixjson',
        'prettierd',
    },
    jsx = {
        'biome',
    },
    julia = {
        'julia_format',
    },
    lua = {
        'stylua',
        'lua-format',
        'luafmt',
    },
    mustache = {
        'biome',
    },
    nix = {
        'alejandra',
    },
    prisma = {
        'prisma_format',
    },
    python = {
        'blackd',
        'yapf',
    },
    scala = {
        'scalafmt',
    },
    sql = {
        'sqlfluff',
        'sql-formatter',
        'pgformatter',
        'sqlfmt',
    },
    typescript = {
        'biome',
        'prettierd',
    },
    typescriptreact = {
        'biome',
        'deno',
    },
    vue = {
        'biome',
    },
    yaml = {
        'biome',
    },
}
---@return vim.fixer.Config
local function load_fixer(name) ---@param name string
    return require('fixers.' .. name)
end
---@param bufnr? integer
---@param opts? table
function M.format(bufnr, opts)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    opts = opts or {}
    local ft = vim.bo[bufnr].filetype
    local names = M.fixers_by_ft[ft]
    if not names or #names == 0 then
        return
    end
    local fixer = load_fixer(names[1])
    local cmd = fixer.cmd ---@type string
    local args = fixer.args or {} ---@type string[]
    local text = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local input = nil
    if fixer.stdin ~= false then
        input = table.concat(text, '\n')
    end
    local full_cmd = { cmd } ---@type string[]
    if #args > 0 then
        vim.list_extend(full_cmd, args)
    end
    vim.system(full_cmd, { text = true, stdin = input }, function(res)
        if res.code ~= 0 and not fixer.allow_non_zero then
            return
        end
        if not res.stdout or res.stdout == '' then
            return
        end
        local new_lines = vim.split(res.stdout, '\n', { plain = true })
        vim.schedule(function()
            if not vim.api.nvim_buf_is_loaded(bufnr) then
                return
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
        end)
    end)
end

return M
