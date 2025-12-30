-- /qompassai/Diver/lsp/bacon.lua
-- Qompass AI Bacon LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'bacon-ls',
  },
  filetypes = {
    'rust',
  },
  init_options = {
    createBaconPreferencesFile = true,
    locationsFile = '.bacon-locations',
    runBaconInBackground = true,
    runBaconInBackgroundCommandArguments = '--headless -j bacon-ls',
    synchronizeAllOpenFilesWaitMillis = 2000,
    updateOnChange = true,
    updateOnSave = true,
    updateOnSaveWaitMillis = 1000,
    useBaconBackend = true,
    validateBaconPreferences = true,
  },
  root_markers = {
    '.bacon-locations',
    'Cargo.lock',
    'Cargo.toml',
    '.git/',
  },
}