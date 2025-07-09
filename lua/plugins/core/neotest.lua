-- /qompassai/Diver/lua/plugins/core/neotest.lua
-- Qompass AI Diver Neotest Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-neotest/neotest-plenary",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "lawrence-laz/neotest-zig",
    "rcasia/neotest-bash",
    "stevanmilic/neotest-scala",
    "thenbe/neotest-playwright",
    "marilari88/neotest-vitest",
    "ibhagwan/fzf-lua",
  },
  cmd = { "Neotest", "NeotestRun", "NeotestSummary", "NeotestOutput" },
  ft = { "lua", "python", "zig", "bash", "scala", "typescript", "javascript" },
  opts = {
    adapters = {
      ["neotest-vitest"] = {},
    },
  },
}
