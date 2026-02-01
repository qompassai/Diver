-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source https://github.com/tree-sitter/tree-sitter/wiki/List-of-parsers
local M = {}
local api = vim.api
local register = vim.treesitter.language.register
local ts = vim.treesitter
function M.treesitter(opts)
    require('nvim-treesitter.install').prefer_git = true
    require('nvim-treesitter.configs').setup(opts)
    local configs = require('nvim-treesitter.configs')
    local parser_dir = vim.g.xdg_data_home .. '/nvim/treesitter'
    vim.opt.runtimepath:prepend(parser_dir)
    require('nvim-treesitter.install').prefer_git = true
    local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
    parser_config.objc = {
        install_info = {
            url = 'https://github.com/merico-dev/tree-sitter-objc',
            files = {
                'src/parser.c',
            },
            branch = 'main',
            generate_requires_npm = false,
            requires_generate_from_grammar = false,
        },
        filetype = 'objc',
    }
    local base_config = { ---@source :lua =require('nvim-treesitter.parsers').get_parser_configs()
        auto_install = true,
        ensure_installed = {
            'ada',
            'agda',
            'angular',
            'apex',
            'arduino',
            'asm',
            'astro',
            --'authzed',
            'awk',
            'bash',
            'bass',
            'beancount',
            'blade',
            'bibtex',
            'bicep',
            'bitbake',
            'blueprint',
            'c',
            'caddy',
            'cairo',
            'clojure',
            'cmake',
            'comment',
            'commonlisp',
            'cpp',
            'c_sharp',
            'css',
            'csv',
            'cuda',
            'cue',
            'd',
            'dart',
            'desktop',
            'devicetree',
            'diff',
            'dockerfile',
            'dot',
            'doxygen',
            'editorconfig',
            'eex',
            'elixir',
            'elm',
            'embedded_template',
            'erlang',
            'facility',
            'faust',
            'fennel',
            'fish',
            'foam',
            'fortran',
            'fsh',
            'fsharp',
            'func',
            'gap',
            'gdscript',
            'gdshader',
            'gitattributes',
            'git_config',
            'git_rebase',
            'gitignore',
            'gleam',
            'glsl',
            'go',
            'goctl',
            'godot_resource',
            'gomod',
            'gosum',
            'gotmpl',
            'gowork',
            'gpg',
            'graphql',
            'gstlaunch',
            'hack',
            'haskell',
            'hcl',
            'helm',
            'hlsl',
            'hoon',
            'html',
            'htmldjango',
            'hyprlang',
            'idl',
            'idris',
            'inko',
            'ini',
            --'ipkg',
            'java',
            'javadoc',
            'jinja',
            'jq',
            'jsdoc',
            'json',
            'json5',
            'jsonc',
            -- 'json_schema',
            'julia',
            'just',
            'kcl',
            'kconfig',
            'kotlin',
            'llvm',
            -- 'llvm_mir',
            'lua',
            'luadoc',
            'luap',
            'luau',
            'latex',
            'm68k',
            'make',
            'markdown',
            'markdown_inline',
            'matlab',
            'mermaid',
            'meson',
            'mlir',
            'nginx',
            'ninja',
            'nix',
            'norg',
            'muttrc',
            'objc',
            'objdump',
            'ocaml',
            'ocaml_interface',
            'ocamllex',
            'odin',
            'passwd',
            'pem',
            'perl',
            'php',
            'php_only',
            'phpdoc',
            'po',
            'powershell',
            'printf',
            'properties',
            'proto',
            'puppet',
            'python',
            'pymanifest',
            'query',
            'r',
            'regex',
            'rego',
            'requirements',
            'rescript',
            'robot',
            'robots',
            'roc',
            'rst',
            'ruby',
            'rust',
            'scala',
            'scfg',
            'scheme',
            'scss',
            'smithy',
            'solidity',
            'sql',
            'ssh_config',
            'starlark',
            'supercollider',
            'superhtml',
            'svelte',
            'sway',
            'swift',
            'tablegen',
            'tcl',
            'teal',
            'templ',
            'terraform',
            'textproto',
            'tiger',
            'tmux',
            'toml',
            'tsv',
            'tsx',
            'turtle',
            'typescript',
            'typst',
            'udev',
            'usd',
            'v',
            'vala',
            'verilog',
            'vhdl',
            'vim',
            'vimdoc',
            'vue',
            'wgsl',
            'wgsl_bevy',
            'xcompose',
            'xml',
            'yaml',
            'yang',
            'zathurarc',
            'zig',
            'ziggy',
            'ziggy_schema',
        },
        highlight = {
            additional_vim_regex_highlighting = false, ---legacy
            enable = true,
        },
        ignore_install = {},
        incremental_selection = {
            enable = true,
            keymaps = {
                init_selection = 'gnn',
                node_decremental = 'grm',
                node_incremental = 'grn',
                scope_incremental = 'grc',
            },
        },
        indent = {
            enable = true,
        },
        move = {
            enable = true,
            set_jumps = true,
            goto_next_end = {
                [']C'] = '@class.outer',
                [']F'] = '@call.outer',
                [']I'] = '@conditional.outer',
                [']L'] = '@loop.outer',
                [']M'] = '@function.outer',
            },
            goto_next_start = {
                [']c'] = '@class.outer',
                [']i'] = '@conditional.outer',
                [']l'] = '@loop.outer',
                [']m'] = '@function.outer',
                [']s'] = {
                    query = '@scope',
                    query_group = 'locals',
                    desc = 'Next scope',
                },
                [']z'] = {
                    query = '@fold',
                    query_group = 'folds',
                    desc = 'Next fold',
                },
            },
            goto_previous_end = {
                ['[C'] = '@class.outer',
                ['[F'] = '@call.outer',
                ['[I'] = '@conditional.outer',
                ['[L'] = '@loop.outer',
                ['[M'] = '@function.outer',
            },
            goto_previous_start = {
                ['[c'] = '@class.outer',
                ['[f'] = '@call.outer',
                ['[i'] = '@conditional.outer',
                ['[l'] = '@loop.outer',
                ['[m'] = '@function.outer',
            },
        },
        parser_install_dir = parser_dir,
        swap = {
            enable = true,
            swap_next = {
                ['<leader>a'] = '@parameter.inner',
                ['<leader>c'] = '@class.outer',
                ['<leader>f'] = '@function.outer',
                ['<leader>l'] = '@loop.outer',
            },
            swap_previous = {
                ['<leader>A'] = '@parameter.inner',
                ['<leader>C'] = '@class.outer',
                ['<leader>F'] = '@function.outer',
                ['<leader>L'] = '@loop.outer',
            },
        },
        sync_install = false,
        textobjects = {
            select = {
                enable = true,
                lookahead = true,
                keymaps = {
                    ['aa'] = '@parameter.outer',
                    ['ac'] = '@class.outer',
                    ['af'] = '@function.outer',
                    ['al'] = '@loop.outer',
                    ['ia'] = '@parameter.inner',
                    ['ic'] = '@class.inner',
                    ['if'] = '@function.inner',
                    ['il'] = '@loop.inner',
                },
            },
            move = {
                enable = true,
                set_jumps = true,
                goto_next_start = {
                    [']m'] = '@function.outer',
                    [']c'] = '@class.outer',
                    [']l'] = '@loop.outer',
                    [']i'] = '@conditional.outer',
                    [']s'] = { query = '@scope', query_group = 'locals', desc = 'Next scope' },
                    [']z'] = { query = '@fold', query_group = 'folds', desc = 'Next fold' },
                },
                goto_next_end = {
                    [']M'] = '@function.outer',
                    [']C'] = '@class.outer',
                    [']L'] = '@loop.outer',
                    [']I'] = '@conditional.outer',
                    [']F'] = '@call.outer',
                },
                goto_previous_start = {
                    ['[m'] = '@function.outer',
                    ['[c'] = '@class.outer',
                    ['[l'] = '@loop.outer',
                    ['[i'] = '@conditional.outer',
                    ['[f'] = '@call.outer',
                },
                goto_previous_end = {
                    ['[M'] = '@function.outer',
                    ['[C'] = '@class.outer',
                    ['[L'] = '@loop.outer',
                    ['[I'] = '@conditional.outer',
                    ['[F'] = '@call.outer',
                },
            },
            swap = {
                enable = true,
                swap_next = {
                    ['<leader>a'] = '@parameter.inner',
                    ['<leader>c'] = '@class.outer',
                    ['<leader>f'] = '@function.outer',
                    ['<leader>l'] = '@loop.outer',
                },
                swap_previous = {
                    ['<leader>A'] = '@parameter.inner',
                    ['<leader>C'] = '@class.outer',
                    ['<leader>F'] = '@function.outer',
                    ['<leader>L'] = '@loop.outer',
                },
            },
        },
    }
    local final_config = vim.tbl_deep_extend('force', base_config, opts or {})
    configs.setup(final_config)
end

function M.tree_cfg(opts)
    opts = opts or {}
    M.treesitter(opts)
    return {
        treesitter = vim.tbl_deep_extend('force', M.options and M.options.treesitter or {}, opts),
    }
end

register('bash', 'sh')
register('bash', 'zsh')
register('c', 'objc')
register('cmake', 'cmake')
register('cpp', 'cpp')
register('css', {
    'postcss',
    'sugarss',
})
register('dockerfile', 'dockerfile')
register('embedded_template', 'eruby')
register('git_config', {
    'gitconfig',
    'gitignore',
})
register('gitcommit', 'gitcommit')
register('glimmer', {
    'javascript.glimmer',
    'typescript.glimmer',
})
register('glsl', 'glsl')
register('go', 'gohtmltmpl')
register('hcl', {
    'hcl',
    'terraform',
})
register('html', {
    'html.antlers',
    'html.handlebars',
})
register('json', 'jsonc')
register('latex', 'tex')
register('linkerscript', 'ld')
register('make', 'make')
register('markdown', {
    'markdown',
    'mdx',
    'rmd',
})
register('sql', 'pgsql')
register('typescript', {
    'typescript',
    'typescriptreact',
})
register('verilog', {
    'verilog',
    'systemverilog',
})
register('yaml', {
    'yaml',
    'yaml.ansible',
    'yaml.docker-compose',
    'yaml.github',
    'yaml.gitlab',
    'yaml.helm-values',
})
api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('TreesitterStart', {
        clear = true,
    }),
    pattern = '*',
    callback = function(args)
        local buf = args.buf
        local lang = ts.language.get_lang(args.match)
        if not lang then
            return
        end
        local buftype = api.nvim_get_option_value('buftype', {
            buf = buf,
        })
        if buftype ~= '' then
            return
        end
        local ok = pcall(function()
            if pcall(ts.language.add, lang) then
                ts.start(buf, lang)
            end
        end)
        if not ok then
            return
        end
    end,
})

return M
