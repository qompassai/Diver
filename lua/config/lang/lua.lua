-- /qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local function lua_home()
    return vim.fn.stdpath('config') .. '/lua'
end
local function lua_library(entries)
    local lib = {}
    for _, item in ipairs(entries or {}) do
        if type(item) == 'string' then
            table.insert(lib, item)
        elseif type(item) == 'table' and item.path then
            table.insert(lib, item.path)
        end
    end
    table.insert(lib, vim.env.VIMRUNTIME)
    table.insert(lib, vim.fn.stdpath('config') .. '/lua')
    table.insert(lib, vim.fn.stdpath('data') .. '/lazy')
    return lib
end
local function lua_version()
    local ver = _VERSION or 'Lua'
    local bin = vim.fn.exepath('lua') ~= '' and vim.fn.exepath('lua') or vim.fn.expand('$XDG_DATA_HOME/lua/bin/lua')
    return ver, bin
end
vim.api.nvim_create_user_command('LuaRangeAction', function()
    local bufnr = 0
    local diagnostics = vim.diagnostic.get(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor.extract',
            },
        },
        range = {
            start = { start_pos[1], start_pos[2] },
            ['end'] = { end_pos[1], end_pos[2] },
        },
        filter = function(_, client_id)
            local client = vim.lsp.get_client_by_id(client_id)
            return client ~= nil and client.name == 'lua_ls'
        end,
        apply = false,
    })
end, { range = true })
function M.lua_cmp()
    if vim.g.use_blink_cmp then
        return {
            sources = {
                {
                    name = 'lsp',
                },
                {
                    name = 'luasnip',
                },
                {
                    name = 'buffer',
                },
                {
                    name = 'nvim_lua',
                    via = 'compat',
                },
                {
                    name = 'lazydev',
                },
            },
            performance = {
                async = true,
                throttle = 50,
            },
            appearance = {
                kind_icons = require('lazyvim.config').icons.kinds,
                nerd_font_variant = 'mono',
                use_nvim_cmp_as_default = false,
            },
            completion = {
                accept = {
                    auto_brackets = true,
                },
                menu = {
                    draw = {
                        treesitter = {
                            'lsp',
                        },
                    },
                },
                documentation = {
                    auto_show = true,
                },
            },
        }
    else
        local cmp = require('cmp')
        return {
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                ['<C-f>'] = cmp.mapping.scroll_docs(4),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
            }),
            sources = {
                {
                    name = 'nvim_lua',
                },
                {
                    name = 'nvim_lsp',
                },
                {
                    name = 'luasnip',
                },
                {
                    name = 'buffer',
                },
            },
            experimental = {
                ghost_text = true,
            },
        }
    end
end

function M.lua_lazydev(opts)
    opts = opts or {}
    return {
        runtime = opts.runtime or vim.env.VIMRUNTIME,
        library = lua_library({
            lua_home(),
        }),
        integrations = {
            cmp = not (opts.integrations and opts.integrations.cmp == false),
            coq = not (opts.integrations and opts.integrations.coq == false),
            lspconfig = not (opts.integrations and opts.integrations.lspconfig == false),
        },
        enabled = opts.enabled or function()
            return vim.g.lazydev_enabled ~= false
        end,
    }
end

function M.lua_luarocks(opts)
    opts = opts or {}
    local config = {
        build = true,
        rocks_path = vim.fn.expand('$XDG_DATA_HOME/lua/luarocks'),
        rocks = {
            'bit32',
            'busted',
            'lua-cjson',
            'dkjson',
            'fzy',
            'httpclient',
            'htmlparser',
            'lpeg',
            'lpugl',
            'lua-lru',
            'luautf8',
            'luacheck',
            'lua-csnappy',
            'luadbi',
            'luafilesystem',
            'luafilesystem-ffi',
            'lua-genai',
            'httprequestparser',
            'luamark',
            'luaproc',
            'luar',
            'luarocks-build-rust-mlua',
            'lua-rtoml',
            'luasocket',
            'luaossl',
            'luasql-postgres',
            'luastruct',
            'lua-resty-http',
            'luasql-postgres',
            'lua-sdl2',
            'luasql-sqlite3',
            'lua-term',
            'lua-toml',
            'luv',
            'lzlib',
            'magick',
            'opengl',
            'penlight',
            'penlight-ffi',
            'phplua',
            'rapidjson',
            'quantum',
            'typecheck',
        },
    }
    local rocks_dir = vim.fn.expand('$XDG_DATA_HOME/nvim/lazy/luarocks.nvim/.rocks')
    if vim.fn.isdirectory(rocks_dir) == 1 then
        config.build = false
    end
    return vim.tbl_deep_extend('force', config, opts)
end

function M.lua_snap(opts)
    opts = opts or {}
    local config = {
        mappings = {
            ['<CR>'] = 'submit',
            ['<C-x>'] = 'cut',
        },
    }
    return vim.tbl_deep_extend('force', config, opts)
end

function M.lua_test(opts)
    opts = opts or {}
    return {
        adapters = {
            require('neotest-plenary')({
                test_file_patterns = {
                    '.*_test%.lua$',
                    '.*_spec%.lua$',
                },
                min_init = 'tests/init.lua',
            }),
        },
        strategies = {
            integrated = {
                args = {
                    '--lua',
                    vim.fn.expand('~/.local/bin/lua5.1'),
                },
            },
        },
        output_panel = {
            open = 'botright split | resize 15',
        },
        discovery = {
            enabled = true,
            filter_dir = function(name)
                return name ~= 'node_modules' and name ~= '.git'
            end,
        },
    }
end

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'lua_ls' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
function M.lua_cfg(opts)
    opts = opts or {}
    local ver, bin = lua_version()
    vim.env.LUA_VERSION = ver
    vim.env.LUA_PATH = bin
    return {
        autocmds = M.lua_autocmds,
        cmp = M.lua_cmp,
        lazydev = M.lua_lazydev(opts),
        luarocks = M.lua_luarocks(opts.luarocks or {}),
        snap = M.lua_snap(opts),
        test = M.lua_test(opts),
        version = ver,
        path = bin,
    }
end

return M