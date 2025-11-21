-- /qompassai/Diver/lsp/bacon.lua
-- Qompass AI Bacon LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['bacon'] = {
  cmd = { 'bacon' },
  filetypes = { 'rust' },
  init_options = {
    init_options = {
      locationsFile = ".bacon-locations",
      updateOnSave = true,
      updateOnSaveWaitMillis = 1000,
      updateOnChange = true,
      validateBaconPreferences = true,
      createBaconPreferencesFile = true,
      runBaconInBackground = true,
      runBaconInBackgroundCommandArguments = "--headless -j bacon-ls",
      synchronizeAllOpenFilesWaitMillis = 2000,
    }
  },
  root_markers = {
    '.bacon-locations',
    'Cargo.toml'
  }
}