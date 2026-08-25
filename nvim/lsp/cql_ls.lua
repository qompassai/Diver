#!/usr/bin/env lua5.1, JIT

-- cql_ls.lua
-- Qompass AI Diver Cassandra Query Language (CQL) LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/Akzestia/cqlls
---
--- Install via cargo:
--- ```sh
--- cargo install cqlls
--- ```

---@type vim.lsp.Config
return {
  cmd = {
    'cqlls',
  },
  filetypes = {
    'cql',
    'cqlang',
  },
  root_markers = {
    '.cqlls',
    '.git',
  },
  settings = {},
}
