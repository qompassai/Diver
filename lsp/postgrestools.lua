-- /qompassai/Diver/lsp/postgrestools.lua
-- Qompass AI PostGresTools LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  cmd = { "postgrestools", "lsp-proxy" },
  filetypes = {
    "sql",
  },
  root_markers = { "postgrestools.jsonc" },
}
