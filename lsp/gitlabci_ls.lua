-- /qompassai/Diver/lsp/gitlabci_ls.lua
-- Qompass AI Gitlab Continuous Integration (CI) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/alesbrelih/gitlab-ci-ls
-- cargo install gitlab-ci-ls
vim.lsp.config['gitlabci_ls'] = {
  cmd = {
    'gitlab-ci-ls'
  },
  filetypes = {
    'yaml.gitlab'
  },
  init_options = {
    cache_path = (
          vim.env.XDG_CACHE_HOME
          or
          (
            vim.env.HOME .. '/.cache'
          )
        )
        .. '/gitlab-ci-ls',
    log_path = (
          (
            vim.env.XDG_CACHE_HOME
            or
            (
              vim.env.HOME .. '/.cache'
            )
          )
          .. '/gitlab-ci-ls'
        )
        .. '/log/gitlab-ci-ls.log',
  },
  root_markers = {
    '.git',
    '.gitlab-ci.yml',
    '.gitlab-ci.yaml'
  },
}