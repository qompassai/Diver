-- /qompassai/Diver/lua/plugins/ui/md.lua
-- Qompass AI Markdown Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local md_cfg = require('config.ui.md')
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
    config = function(_, opts)
      md_cfg.md_rendermd(opts)
    end
  },
  {
    'arminveres/md-pdf.nvim',
    dependencies = { '3rd/diagram.nvim' },
    opts = function() return md_cfg.md_pdf() end,
    config = function(_, opts) md_cfg.md_pdf(opts) end
  },
  {
    "brianhuster/live-preview.nvim",
    ft = { "markdown", "html", "asciidoc" },
    cmd = { "LivePreview" },
    dependencies = {
      "ibhagwan/fzf-lua",
    },
    config = function(_, opts)
      md_cfg.md_livepreview(opts)
    end,
  },
  { '3rd/diagram.nvim' },
  dependencies = { '3rd/image.nvim' },
  config = function(_, opts)
    md_cfg.md_diagram(opts)
  end
}
