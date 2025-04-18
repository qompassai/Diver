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
		lazy = true,
		dependencies = {
			"3rd/image.nvim",
		},
		config = function()
			require("diagram").setup({
				integrations = {
					require("diagram.integrations.markdown"),
					require("diagram.integrations.neorg"),
				},
				opts = {
					rocks = {
						hererocks = true,
						enabled = true,
					},
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
							theme_id = "neutral",
							dark_theme_id = "dark",
							scale = 1.0,
							layout = "dagre",
							sketch = true,
						},
					},
				},
			})
		end,
	},

	{
		"3rd/image.nvim",
		lazy = true,
		config = function()
			require("image").setup({
				backend = "kitty",
				processor = "magick_rock",
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
					typst = {
						enabled = true,
						filetypes = { "typst" },
					},
					html = {
						enabled = true,
					},
					css = {
						enabled = true,
					},
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
			})
		end,
	},
}
