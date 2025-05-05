return {
  {
    "arminveres/md-pdf.nvim",
    ft = "markdown",
    dependencies = { "3rd/diagram.nvim" },
    keys = {
      {
        "<leader>,",
        function() require("md-pdf").convert_md_to_pdf() end,
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
  },
  {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreview", "MarkdownPreviewToggle", "MarkdownPreviewStop" },
  ft = { "markdown" },
  build = ":call mkdp#util#install()",
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
},
  {
  "3rd/diagram.nvim",
  ft = { "markdown", "norg" },
  dependencies = { "3rd/image.nvim" },
  opts = {
    events = {
      render_buffer = { "BufWritePost" },
      clear_buffer = { "BufLeave" },
    },
    integrations = {
      "markdown",
      "neorg",
    },
    renderer_options = {
      mermaid = {
        background = "transparent",
        theme = "dark",
        scale = 1,
      },
      plantuml = { charset = "utf-8" },
      d2 = {
        theme_id = "neutral",
        dark_theme_id = "dark",
        scale = 1.0,
        layout = "dagre",
        sketch = true,
      },
    },
    auto_render = true,
    open_app = false,
    rocks = {
      hererocks = false,
      enabled = true,
    },
  },
  config = function(_, opts)
    local integrations = {}
    for _, integration in ipairs(opts.integrations) do
      table.insert(integrations, require("diagram.integrations." .. integration))
    end
    opts.integrations = integrations
    require("diagram").setup(opts)
    vim.api.nvim_create_user_command("DiagramRender", function()
      require("diagram").render_buffer()
    end, {})
  end,
},
  {
    "3rd/image.nvim",
    ft = { "markdown", "norg", "typst", "html", "css" },
    opts = {
      backend = "kitty",
      processor = "magick_rock",
      backend_options = {
      kitty = {
        term_program_detection = true,
        use_terminal_cmd_image_protocol = true
      }
    },
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
        neorg = {
          enabled = true,
          filetypes = { "norg" },
        },
        typst = { enabled = true, filetypes = { "typst" } },
        html = { enabled = true },
        css = { enabled = true },
      },
      max_width = 800,
      max_height = 600,
      max_width_window_percentage = 80,
      max_height_window_percentage = 50,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
      editor_only_render_when_focused = false,
      tmux_show_only_in_active_window = false,
      hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    },
  },
  {
    "img-paste-devs/img-paste.vim",
    ft = { "markdown" },
    cmd = "PasteImg",
    keys = {
      { "<C-a>", "<cmd>PasteImg<CR>", desc = "Paste Image from Clipboard", ft = "markdown" },
    },
    init = function()
      vim.g.mdip_imgdir = 'images'
      vim.g.mdip_imgname = 'image'
    end,
  },
}
