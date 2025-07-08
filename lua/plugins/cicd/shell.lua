-- qompassai/Diver/lua/plugins/cicd/sops.lua
-- Qompass AI Diver Shell Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  {
    'trixnz/sops.nvim',
    ft = {
      'yaml', 'yml', 'json', 'toml', 'env', 'nix', 'ini', 'conf', 'key',
      'gpg', 'asc'
    },
    opts = {
      file_patterns = { '*.conf', '*.config', '*.cnf', '*.key', '*.enc' }
    }
  }
}
