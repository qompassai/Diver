-- /qompassai/Diver/lsp/docker_ls.lua
-- Qompass AI Docker LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- go install github.com/docker/docker-language-server/cmd/docker-language-server@latest
vim.lsp.config["docker-language-server"] = {
  cmd = {
    "docker-language-server",
    "start",
    "--stdio",
  },
  filetypes = {
    "dockerfile",
    "yaml.docker-compose",
  },
  root_markers = {
    "Dockerfile",
    "docker-compose.yaml",
    "docker-compose.yml",
    "compose.yaml",
    "compose.yml",
    "docker-bake.json",
    "docker-bake.hcl",
    "docker-bake.override.json",
    "docker-bake.override.hcl",
  },
}