-- qompassai/Diver/lua/config/cicd/shell.lua
-- Qompass AI Diver CICD Shell Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.sh_conform(opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters_by_ft.sh = {'shfmt'}
    opts.formatters = vim.tbl_deep_extend('force', opts.formatters or {}, {
        shfmt = vim.fn.executable('shfmt') == 1 and
            {command = 'shfmt', args = {'-i', '2', '-ci', '-'}, stdin = true} or
            nil
    })
    return opts
end
function M.sh_lsp(opts)
    opts.servers = opts.servers or {}
    opts.servers.bashls = {
        filetypes = {'sh', 'bash', 'ksh', 'csh', 'tcsh'},
        settings = {
            bashIde = {
                globPattern = '*@(.sh|.bash|.inc|.command|.ksh|.csh|.tcsh)',
                backgroundAnalysisMaxFiles = 500,
                enableSourceErrorDiagnostics = true,
                shellcheckPath = 'shellcheck',
                explainshellEndpoint = '',
                includeAllWorkspaceSymbols = true
            }
        }
    }

    opts.servers.fish_ls = {filetypes = {'fish'}}
    opts.servers.nushell = {filetypes = {'nu'}}
    opts.servers.zls = {filetypes = {'zsh'}}
    opts.servers.powershell_es = {
        filetypes = {'ps1', 'psm1'},
        settings = {
            powershell = {
                codeFormatting = { Preset = "OTBS" }
            }
        }
    }
    opts.capabilities = opts.capabilities or {}
    return opts
end
function M.sh_linter(opts)
    local null_ls = require('null-ls')
    local shellcheck = require('none-ls-shellcheck')
    opts.sources = vim.list_extend(opts.sources or {}, {
        shellcheck.diagnostics, null_ls.builtins.diagnostics.fish,
        null_ls.builtins.diagnostics.zsh, shellcheck.code_actions, null_ls.builtins.formatting.fish_indent
    })
    opts.root_dir = M.detect_sh_root_dir
    return opts
end
function M.detect_sh_root_dir(fname)
    local util = require('lspconfig.util')
    local root = util.root_pattern('.git')(fname)
    local stat = vim.uv.fs_stat(fname)
    if not stat or stat.type ~= 'file' then return root end
    local file = io.open(fname, 'r')
    if file then
        local first_line = file:read()
        file:close()
        if first_line and
            (first_line:match('^#!.*sh') or first_line:match('^#!.*zsh') or
                first_line:match('^#!.*fish') or first_line:match('^#!.*nu')) then
            return root or vim.fn.getcwd()
        end
    end
    return root
end
function M.sh_filetype_detection()
    vim.filetype.add({
        extension = {
            sh = 'bash',
            bash = 'bash',
            zsh = 'zsh',
            fish = 'fish',
            nu = 'nu'
        },
        pattern = {
            ['.*.sh'] = 'bash',
            ['.*.bash'] = 'bash',
            ['.bash*'] = 'bash',
            ['.*.zsh'] = 'zsh',
            ['.zsh*'] = 'zsh',
            ['.*.fish'] = 'fish',
            ['.*.nu'] = 'nu'
        },
        filename = {
            ['.bashrc'] = 'bash',
            ['.zshrc'] = 'zsh',
            ['config.fish'] = 'fish'
        }
    })
end
function M.sh_keymaps(opts)
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>cs'] = {name = '+shell'},
        ['<leader>csf'] = {
            "<cmd>lua require('conform').format()<cr>", 'Format Shell Script'
        },
        ['<leader>csc'] = {
            '<cmd>lua vim.lsp.buf.code_action()<cr>', 'Shell Code Actions'
        },
        ['<leader>csl'] = {
            '<cmd>TroubleToggle lsp_document_diagnostics<cr>',
            'Shell Lint Issues'
        }
    })
    return opts
end
return M
