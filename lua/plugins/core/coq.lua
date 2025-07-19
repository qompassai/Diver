-- /qompassai/Diver/lua/plugins/core/coq.lua
-- Qompass AI Conquer of Completion (Coq) Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  {
    "ms-jpq/coq_nvim",
		version = '*',
    dependencies = {
      { "ms-jpq/coq.artifacts", branch = "artifacts" },
      { "ms-jpq/coq.thirdparty", branch = "3p" }
    },
    init = function()
      vim.g.coq_settings = {
        auto_start = false,
      }
    end,
    config = function()
    end,
  },
}
