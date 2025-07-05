-- qompassai/Diver/lua/config/cicd/ansible.lua
-- Qompass AI Diver CICD Ansible Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.ansible_conform(opts)
  opts = opts or {}
  local conform_cfg = require("config.lang.conform")
  return {
    formatters_by_ft = {
      ansible = {'ansible_lint'},
        yaml = {'biome'},
        yml = {'biome'},
        ["yaml.ansible"] = {'ansible_lint'}
      },
    format_on_save = conform_cfg.format_on_save,
    format_after_save = conform_cfg.format_after_save,
    default_format_opts = conform_cfg.default_format_opts,
  }
end
function M.ansible_lsp(on_attach, capabilities)
    return {
        ansiblels = {
            cmd = {'ansible-language-server', '--stdio'},
            filetypes = {'yaml.ansible', 'ansible'},
            settings = {
                ansible = {
                    ansible = {path = 'ansible'},
                    executionEnvironment = {enabled = true},
                    python = {interpreterPath = 'python'},
                    validation = {
                        enabled = true,
                        lint = {enabled = true, path = 'ansible-lint'}
                    }
                }
            },
            on_attach = function(client, bufnr)
                vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
                if on_attach then on_attach(client, bufnr) end
            end,
            capabilities = capabilities or
                vim.lsp.protocol.make_client_capabilities()
        }
    }
end
function M.ansible_nls()
    local null_ls = require('null-ls')
    local fmt = null_ls.builtins.formatting
    local diag = null_ls.builtins.diagnostics
    local ca = null_ls.builtins.code_actions
    return {
        diag.ansiblelint.with({
            method = null_ls.methods.DIAGNOSTICS,
            ft = {'yaml.ansible', 'ansible'},
            extra_args = {'--parseable-severity'}
        }), diag.yamllint.with({
            method = null_ls.methods.DIAGNOSTICS,
            ft = {'yaml', 'yaml.ansible'},
            cmd = 'yamllint'
        }), fmt.prettierd.with({
            method = null_ls.methods.FORMATTING,
            ft = {'yaml', 'yaml.ansible', 'ansible'},
            extra_args = {'--parser', 'yaml'}
        }), ca.statix.with({
            method = null_ls.methods.CODE_ACTION,
            ft = {'yaml.ansible', 'ansible'}
        })
    }
end
function M.ansible_ts()
    local ok, ts_configs = pcall(require, 'nvim-treesitter.configs')
    if ok then
        ts_configs.setup({
            ensure_installed = {'yaml'},
            auto_install = true,
            sync_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = true
            },
            indent = {enable = true}
        })
    end
end
function M.ansible_filetype_autocmd()
    vim.api.nvim_create_autocmd({'BufRead', 'BufNewFile'}, {
        pattern = {
            '*/playbooks/*.yml', '*/roles/*.yml', '*/inventory/*.yml',
            '*/host_vars/*.yml', '*/group_vars/*.yml'
        },
        callback = function() vim.bo.filetype = 'yaml.ansible' end
    })
end
---@param opts? { on_attach?: fun(client,bufnr), capabilities?: table }
function M.ansible_cfg(opts)
  opts = opts or {}
  M.ansible_ts()
  M.ansible_filetype_autocmd()
  return {
    conform  = M.ansible_conform(opts),
    lsp      = M.ansible_lsp(opts.on_attach, opts.capabilities),
    nls      = M.ansible_nls(),
  }
end
return M
