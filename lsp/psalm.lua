-- /qompassai/diver/lsp/psalm.lua
-- Qompass AI Diver Psalm LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local filetypes = {
  "php",
  "phps",
  "blade",
}
local root_markers = {
  "psalm.xml",
  "psalm.xml.dist",
  "composer.jsonc",
  ".git",
}
local function get_language_id(_, filetype)
  if filetype == "php" then
    return "php"
  elseif filetype == "phps" then
    return "php"
  elseif filetype == "blade" then
    return "blade"
  else
    return filetype
  end
end
local enabled_ids = {}
do
  local enabled_keys = {}
  for _, ft in ipairs(filetypes) do
    local id = get_language_id({}, ft)
    if not enabled_keys[id] then
      enabled_keys[id] = true
      table.insert(enabled_ids, id)
    end
  end
end
return {
  cmd = { "php", "vendor/bin/psalm-language-server" },
  filetypes = filetypes,
  root_markers = root_markers,
  get_language_id = get_language_id,
  settings = {
    psalm = {
      enabled = enabled_ids,
      errorLevel = 2,
      phpVersion = "8.4",
      reportUnusedCode = true,
      severity = "all",
      showHints = true,
      showInfo = true,
      showSuggestions = true,
      strictTyping = true,
      useCache = true,
    },
  },
}
