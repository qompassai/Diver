-- /qompassai/Diver/lsp/deno.lua
-- Deno Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://docs.deno.com/runtime/reference/lsp_integration/
local xdg = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
return {
  cmd = { "deno", "lsp" },
  filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  root_dir = require("lspconfig.util").root_pattern("deno.json", "deno.jsonc", "tsconfig.json", ".git"),
  init_options = {
    enable = true,
    lint = true,
    unstable = true,
    suggest = {
      paths = true,
      autoImports = true,
      completeFunctionCalls = true,
      imports = {
        autoDiscover = true,
        hosts = { "https://deno.land", "https://cdn.nest.land", "https://crux.land" },
      },
    },
    codeLens = {
      implementations = true,
      references = true,
      referencesAllFunctions = true,
      test = true,
    },
    importMap = xdg .. "/deno/import_map.jsonc",
    config = xdg .. "/deno/deno.jsonc",
    cache = os.getenv("XDG_CACHE_HOME") and (os.getenv("XDG_CACHE_HOME") .. "/deno_cache")
      or (os.getenv("HOME") .. "/.cache/deno_cache"),
    internalDebug = true,
    certificateStores = {},
    tlsCertificate = "",
    unsafelyIgnoreCertificateErrors = false,
  },
}
