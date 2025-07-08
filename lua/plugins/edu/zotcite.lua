-- /qompassai/Diver/lua/plugins/edu/zotcite.lua
-- Qompass AI Diver Zotcite Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local zotcite_cfg = require("config.edu.zotcite")
return {
  "jalvesaq/zotcite",
  dependencies = {"ibhagwan/fzf-lua"},
  ft    = { "markdown", "rmd", "quarto", "vimwiki" },
  config = function(_, opts)
    zotcite_cfg.zotcite_cfg(opts)
  end,
}
