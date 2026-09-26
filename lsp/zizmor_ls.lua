#!/usr/bin/env lua
--- zizmor language-server config — starts the GitHub Actions workflow files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `zizmor` tutor whenever you open GitHub Actions workflow files. It only
--- takes effect if `zizmor` is installed on your computer. Zizmor is a security auditor for CI workflows.
---@module 'lsp.zizmor_ls'

-- zizmor_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- https://github.com/zizmorcore/zizmor
---
--- Zizmor language server.
---
--- `zizmor` can be installed by following the instructions [here](https://docs.zizmor.sh/installation/).
---
--- The default `cmd` assumes that the `zizmor` binary can be found in `$PATH`.
---
--- See `zizmor`'s [documentation](https://docs.zizmor.sh/) for additional documentation.

---@type vim.lsp.Config
return {
    cmd = { 'zizmor', '--lsp' },
    filetypes = { 'yaml' },

    -- `root_dir` ensures that the LSP does not attach to all yaml files
    root_dir = function(bufnr, on_dir)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local parent = vim.fs.dirname(bufname)
        if
            vim.endswith(parent, '/.github/workflows')
            or vim.endswith(parent, '/.forgejo/workflows')
            or vim.endswith(parent, '/.gitea/workflows')
            or (vim.endswith(bufname, '/.github/dependabot.yml') or vim.endswith(bufname, '/.github/dependabot.yaml'))
            -- Composite actions can live in any repository subdirectory
            or (vim.endswith(bufname, 'action.yml') or vim.endswith(bufname, 'action.yaml'))
        then
            on_dir(parent)
        end
    end,
    init_options = {}, -- needs to be present https://github.com/neovim/nvim-lspconfig/pull/3713#issuecomment-2857394868
    capabilities = {
        workspace = {
            didChangeWorkspaceFolders = {
                dynamicRegistration = true,
            },
        },
    },
}
