-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Autocmds Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
---@return string
local function get_relative_path(filepath) ---@param filepath string
    local qompass_idx = filepath:find('/qompassai/')
    if qompass_idx then
        return filepath:sub(qompass_idx + 1)
    else
        local rel = vim.fn.fnamemodify(filepath, ':~:.')
        return rel
    end
end
local function make_header(filepath, comment)
    local relpath = get_relative_path(filepath)
    local description = 'Qompass AI - [ ]' ---@type string
    local copyright = 'Copyright (C) 2026 Qompass AI, All rights reserved' ---@type string
    local solid ---@type string
    if comment == '<!--' then
        solid = '<!-- ' .. string.rep('-', 40) .. ' -->'
        return {
            '<!-- ' .. relpath .. ' -->',
            '<!-- ' .. description .. ' -->',
            '<!-- ' .. copyright .. ' -->',
            solid,
        }
    elseif comment == '/*' then
        solid = '/* ' .. string.rep('-', 40) .. ' */'
        return {
            '/* ' .. relpath .. ' */',
            '/* ' .. description .. ' */',
            '/* ' .. copyright .. ' */',
            solid,
        }
    else
        solid = comment .. ' ' .. string.rep('-', 40)
        return {
            comment .. ' ' .. relpath,
            comment .. ' ' .. description,
            comment .. ' ' .. copyright,
            solid,
        }
    end
end
M = M or {}
vim.cmd([[autocmd BufRead,BufNewFile *.hcl set filetype=hcl]])
vim.cmd([[autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform]])
vim.api.nvim_create_autocmd('CmdlineChanged', {
    pattern = {
        ':',
        '/',
        '?',
    },
    callback = function()
        vim.fn.wildtrigger()
    end,
})
vim.api.nvim_create_autocmd({
    'FocusGained',
    'BufEnter',
    'CursorHold',
    'CursorHoldI',
}, {
    callback = function()
        if vim.bo.filetype ~= '' and vim.bo.filetype ~= 'vim' and vim.fn.mode() ~= 'c' then
            vim.cmd('checktime')
        end
    end,
})
vim.api.nvim_create_autocmd(
    'BufNewFile', ---@type string
    {
        pattern = '*', ---@type string
        callback = function()
            local filepath = vim.fn.expand('%:p')
            local ext = vim.fn.expand('%:e')
            local filetype = vim.bo.filetype
            local comment_map = { ---@type table[]
                arduino = '//',
                asciidoc = '//',
                asm = ';',
                astro = '//',
                avro = '#',
                bash = '#',
                bicep = '//',
                c = '//',
                cf = '#',
                cff = '#',
                cfn = '#',
                clojure = ';',
                cmake = '#',
                compute = '//',
                conf = '#',
                cpp = '//',
                cs = '//',
                css = '/*',
                cuda = '//',
                cue = '//',
                dhall = '--',
                dockerfile = '#',
                dosini = ';',
                elixir = '#',
                fish = '#',
                fix = '#',
                glsl = '//',
                go = '//',
                graphql = '#',
                h = '//',
                haskell = '--',
                hlsl = '//',
                hocon = '#',
                hpp = '//',
                html = '<!--',
                ini = ';',
                java = '//',
                javascript = '//',
                javascriptreact = '//',
                js = '//',
                json = '//',
                jsonc = '//',
                julia = '#',
                kotlin = '//',
                latex = '%',
                less = '/*',
                lua = '--',
                markdown = '<!--',
                md = '<!--',
                mdx = '//',
                meson = '#',
                mlir = '//',
                mojo = '#',
                mql4 = '//',
                mql5 = '//',
                nix = '#',
                opencl = '//',
                openqasm = '//',
                parquet = '#',
                perl = '#',
                php = '//',
                pine = '//',
                pl = '#',
                plsql = '--',
                powershell = '#',
                proto = '//',
                protobuf = '//',
                py = '#',
                python = '#',
                qsharp = '//',
                quil = '#',
                r = '#',
                rb = '#',
                renderdoc = '#',
                rmd = '#',
                rs = '//',
                rst = '..',
                ruby = '#',
                rust = '//',
                sass = '//',
                scala = '//',
                scm = ';',
                scss = '/*',
                sh = '#',
                sql = '--',
                svelte = '//',
                swift = '//',
                systemverilog = '//',
                terraform = '#',
                tex = '%',
                toml = '#',
                ts = '//',
                typescript = '//',
                typescriptreact = '//',
                unity = '//',
                verilog = '//',
                vhdl = '--',
                vim = '"',
                vue = '//',
                wasm = ';;',
                wat = ';;',
                x86asm = ';',
                xml = '<!--',
                yaml = '#',
                yml = '#',
                zig = '//',
                zsh = '#',
            }
            local comment = comment_map[ext] or comment_map[filetype] or '#'
            if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '' then
                local header = make_header(filepath, comment)
                vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
                vim.cmd('normal! G')
            end
        end,
    }
)

vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        'tex',
        'plaintex',
    },
    callback = function()
        vim.wo.wrap = true
        vim.wo.linebreak = true
        vim.wo.breakindent = true
    end,
})
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        'sqlite',
        'pgsql',
    },
    callback = function()
        vim.opt_local.expandtab = true
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.omnifunc = 'vim_dadbod_completion#omni'
    end,
})

local largefile_group = vim.api.nvim_create_augroup('LargeFile', {})
vim.api.nvim_create_autocmd({
    'BufReadPre',
    'FileReadPre',
}, {
    group = largefile_group,
    callback = function(args)
        local ok, stat = pcall(vim.loop.fs_stat, args.file)
        if not ok or not stat then
            return
        end
        local limit = 20 * 1024 * 1024
        if stat.size < limit then
            return
        end
        vim.b.large_file = true
        vim.opt_local.swapfile = false
        vim.opt_local.undofile = false
        vim.opt_local.foldmethod = 'manual'
        vim.opt_local.syntax = 'off'
        pcall(vim.treesitter.stop, args.buf)
        for _, client in
            ipairs(vim.lsp.get_clients({
                bufnr = args.buf,
            }))
        do
            vim.lsp.buf_detach_client(args.buf, client.id)
        end
    end,
})
vim.api.nvim_create_user_command('VitestFile', function()
    local file = vim.fn.expand('%:p')
    vim.fn.jobstart({ 'vitest', 'run', file }, {
        detach = true,
    })
end, {})
vim.api.nvim_create_user_command('ConfigSelfCheck', function()
    require('tests.selfcheck').run()
end, {})
local function strip_ansi()
    vim.cmd([[%s/[\x1b]\[[0-9;]*m//g]])
end
vim.api.nvim_create_autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        if vim.bo.filetype == 'nvimpager' then
            strip_ansi()
        end
    end,
})
return M
