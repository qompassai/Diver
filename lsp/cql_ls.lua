#!/usr/bin/env lua

-- cql_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- https://github.com/Akzestia/cqlls
---
--- Install via cargo:
--- ```sh
--- cargo install cqlls
--- ```

---@type vim.lsp.Config
return {
  cmd = { 'cqlls' },
  filetypes = { 'cql', 'cqlang' },
  root_markers = { '.cqlls', '.git' },
  settings = {},
}
