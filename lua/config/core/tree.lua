-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver Tree-sitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------
local M = {}
local api = vim.api
---@type string[]
local parsers = {
    'ada',
    'agda',
    'angular',
    'apex',
    'arduino',
    'asm',
    'astro',
    'awk',
    'bash',
    'bass',
    'beancount',
    'bibtex',
    'bicep',
    'bitbake',
    'blade',
    'bp',
    'c',
    'c_sharp',
    'caddy',
    'cairo',
    'clojure',
    'cmake',
    'comment',
    'commonlisp',
    'cpp',
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
    'java',
    'javadoc',
    'jinja',
    'jq',
    'jsdoc',
    'json',
    'json5',
    'julia',
    'just',
    'kcl',
    'kconfig',
    'kotlin',
    'latex',
    'llvm',
    'lua',
    'luadoc',
    'luap',
    'luau',
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
    'pymanifest',
    'python',
    'query',
    'r',
    'regex',
    'rego',
    'requirements',
    'rescript',
    'robot',
    'robots_txt',
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
    'systemverilog',
    'tablegen',
    'tcl',
    'teal',
    'templ',
    'terraform',
    'textproto',
    'tiger',
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
    'zig',
    'ziggy',
    'ziggy_schema',
    'zsh',
}

local function register_languages()
    vim.treesitter.language.register('json', 'jsonc')
    vim.treesitter.language.register('markdown', 'mdx')
    vim.treesitter.language.register('systemverilog', 'verilog')

    vim.treesitter.language.register('hcl', {
        'atlas-config',
        'atlas-schema-mysql',
        'atlas-schema-postgresql',
        'atlas-schema-sqlite',
        'atlas-schema-clickhouse',
        'atlas-schema-mssql',
        'atlas-schema-redshift',
        'atlas-test',
        'atlas-plan',
        'atlas-rule',
    })
end

local BUFFER_BYTES_MAX = 2 * 1024 * 1024
local CAPTURES_MAX = 20000
local configured = {}
local options = {}

local function parser_for(bufnr)
    if not api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].buftype ~= '' then
        return
    end
    local size = api.nvim_buf_get_offset(bufnr, api.nvim_buf_line_count(bufnr))
    if size < 0 or size > BUFFER_BYTES_MAX then
        return
    end
    return vim.treesitter.get_parser(bufnr, nil, { error = false })
end

local function attach(bufnr)
    local parser = parser_for(bufnr)
    if not parser then
        return
    end
    if options.highlight ~= false then
        local ok, err = pcall(vim.treesitter.start, bufnr)
        if not ok then
            vim.notify('Tree-sitter: ' .. tostring(err), vim.log.levels.WARN)
        end
    end
    if options.folds then
        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
            if not configured[win] then
                configured[win] = { method = vim.wo[win].foldmethod, expr = vim.wo[win].foldexpr }
            end
            vim.wo[win].foldmethod = 'expr'
            vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        end
    end
end

---Use installed query captures without depending on a textobjects plugin.
---@param capture string For example 'function.outer', 'class.outer', or 'fold'.
---@param forward? boolean Defaults to next; false means previous.
---@param ending? boolean Jump to the last included byte instead of the start.
---@param query_name? string Defaults to 'textobjects'.
---@return boolean? jumped True when the cursor moved to a match.
---@return string? err Plain-language reason when nothing matched; only set when jumped is nil.
function M.jump(capture, forward, ending, query_name)
    assert(type(capture) == 'string' and #capture <= 128)
    local bufnr = api.nvim_get_current_buf()
    local parser = parser_for(bufnr)
    if not parser then
        return nil, 'No installed parser, or buffer exceeds 2 MiB'
    end
    local query = vim.treesitter.query.get(parser:lang(), query_name or 'textobjects')
    if not query then
        return nil, 'No installed ' .. (query_name or 'textobjects') .. ' query'
    end
    local trees = parser:parse()
    if not trees or not trees[1] then
        return nil, 'Parser returned no tree'
    end
    local cursor, best, visited = api.nvim_win_get_cursor(0), nil, 0
    local function before(a, b)
        return a[1] < b[1] or a[1] == b[1] and a[2] < b[2]
    end
    for id, node in query:iter_captures(trees[1]:root(), bufnr) do
        visited = visited + 1
        if visited > CAPTURES_MAX then
            return nil, 'Capture budget exceeded'
        end
        if query.captures[id] == capture:gsub('^@', '') then
            local sr, sc, er, ec = node:range()
            local target = { sr + 1, sc }
            if ending then
                if ec == 0 and er > sr then
                    local line = api.nvim_buf_get_lines(bufnr, er - 1, er, false)[1] or ''
                    target = { er, math.max(0, #line - 1) }
                else
                    target = { er + 1, math.max(0, ec - 1) }
                end
            end
            if
                forward ~= false and before(cursor, target) and (not best or before(target, best))
                or forward == false and before(target, cursor) and (not best or before(best, target))
            then
                best = target
            end
        end
    end
    if not best then
        return nil, 'No matching capture in that direction'
    end
    vim.cmd("normal! m'")
    api.nvim_win_set_cursor(0, best)
    return true
end

function M.teardown()
    for win, saved in pairs(configured) do
        if api.nvim_win_is_valid(win) and vim.wo[win].foldexpr == 'v:lua.vim.treesitter.foldexpr()' then
            vim.wo[win].foldmethod, vim.wo[win].foldexpr = saved.method, saved.expr
        end
    end
    configured = {}
    local group = vim.fn.exists('#DiverNativeTree') == 1
    if group then
        api.nvim_del_augroup_by_name('DiverNativeTree')
    end
end

function M.setup(opts)
    assert(opts == nil or type(opts) == 'table')
    M.teardown()
    options = vim.deepcopy(opts or {})
    register_languages()
    local group = api.nvim_create_augroup('DiverNativeTree', { clear = true })
    api.nvim_create_autocmd({ 'BufWinEnter', 'FileType' }, {
        group = group,
        callback = function(args)
            attach(args.buf)
        end,
    })
    for _, buf in ipairs(api.nvim_list_bufs()) do
        attach(buf)
    end
end

-- Compatibility entry points. Parsers/queries must be installed on runtimepath.
-- Native filetype indentation is retained; Neovim has no generic TS indent installer.
M.parsers = parsers
M.treesitter = M.setup
function M.textobjects()
    return M.jump
end
return M
