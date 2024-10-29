return {
  {
    "arminveres/md-pdf.nvim",
    lazy = true,
    dependencies = {
      "3rd/diagram.nvim",
    },
    branch = "main",
    keys = {
      {
        "<leader>,",
        function()
          require("md-pdf").convert_md_to_pdf()
        end,
        desc = "Convert Markdown to PDF",
      },
    },
    opts = {
      pdf_engine = "pandoc",
      pdf_engine_opts = "--pdf-engine=xelatex",
      extra_opts = "--variable=mainfont:Arial --variable=fontsize:12pt",
      output_path = "./",
      auto_open = true,
      pandoc_path = "/usr/bin/pandoc",
      theme = "default",
      margins = "1in",
      toc = true,
      highlight = "tango",
    },
    config = function(_, opts)
      require("md-pdf").setup(opts)
    end,
  },
  {
    "3rd/diagram.nvim",
    dependencies = {
      "3rd/image.nvim",
    },
    config = function()
      require("diagram").setup {
        integrations = {
          require "diagram.integrations.markdown",
          require "diagram.integrations.neorg",
        },
        opts = {
          renderer_options = {
            mermaid = {
              background = "transparent",
              theme = "dark",
              scale = 1,
            },
            plantuml = {
              charset = "utf-8",
            },
            d2 = {
              theme_id = nil,
              dark_theme_id = nil,
              scale = nil,
              layout = nil,
              sketch = nil,
            },
          },
        },
      }
    end,
  },
}
