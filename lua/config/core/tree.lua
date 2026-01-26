-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source https://github.com/tree-sitter/tree-sitter/wiki/List-of-parsers
---@module 'config.core.tree'
local M = {}
---@param bufnr integer|nil
---@param lang  string|nil
---@return string|nil error_message
---@return vim.treesitter.LanguageTree|nil parser
local function safe_get_parser(bufnr, lang)
    local ok, parser_or_err, err = pcall(vim.treesitter.get_parser, bufnr, lang, {
        error = false,
    })
    if not ok or not parser_or_err then
        local msg = err
        if msg == nil and type(parser_or_err) == 'string' then
            msg = parser_or_err
        end
        return msg, nil
    end
    return nil, parser_or_err
end
M.safe_get_parser = safe_get_parser
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        '*',
    },
    callback = function(args)
        local err, parser = safe_get_parser(args.buf, nil)
        if err ~= nil then
            vim.notify('treesitter parser error: ' .. err, vim.log.levels.WARN)
            return
        end
        if parser ~= nil then
            vim.treesitter.start(args.buf)
            vim.bo[args.buf].syntax = 'ON'
        end
    end,
})
function M.treesitter(opts)
    require('nvim-treesitter.install').prefer_git = true
    require('nvim-treesitter.configs').setup(opts)
    local configs = require('nvim-treesitter.configs')
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
            additional_vim_regex_highlighting = true, ---legacy
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
        },
    }
    local final_config = vim.tbl_deep_extend('force', base_config, opts or {}) ---@cast final_config TSConfig
    configs.setup(final_config)
end

function M.tree_cfg(opts)
    opts = opts or {}
    M.treesitter(opts)
    return {
        treesitter = vim.tbl_deep_extend('force', M.options and M.options.treesitter or {}, opts),
    }
end

vim.treesitter.language.register('bash', 'zsh')
vim.treesitter.language.register('bash', 'sh')
vim.treesitter.language.register('json', 'jsonc')
vim.treesitter.language.register('latex', 'tex')
vim.treesitter.language.register('linkerscript', 'ld')
vim.treesitter.language.register('markdown', 'rmd')
vim.treesitter.query.set(
    'c',
    'highlights',
    [[;inherits c
  (identifier) @spell
 (comment) @comment @spell
    (string)  @string  @spell
  ]]
)
return M
