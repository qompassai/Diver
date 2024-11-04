return {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    config = function()
        require('avante_lib').load()
        require("avante").setup({
            opts = {
                enable = true,
                languages = {
                    lua = true,
                    python = true,
                },
                ui = {
                    theme = "auto",
                    border = "rounded", -- (options: "none", "single", "double", "rounded", "solid", "shadow")
                    transparency = 0.9, -- Transparency level of UI elements (range 0.0 to 1.0)
                },
                preview = {
                    enable = true,          -- Enable preview feature
                    max_line_length = 1000, -- Limit preview for files with more lines
                    auto_update = true,     -- Automatically update preview when file changes
                },
                integrations = {
                    treesitter = true,
                    dressing = true,   -- Enable or disable Dressing integration for prompts and UIs
                    nui = true,        -- Enable NUI integration for additional UI elements
                    devicons = "auto", -- Automatically choose between `nvim-web-devicons` or `mini.icons` based on availability
                },
                repo_map = {
                    enabled = true,
                    path = vim.fn.stdpath("data") .. "/avante/repo_map",
                },
            }
        })
    end,
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "neovim/nvim-lspconfig",
        "stevearc/dressing.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
        {
            "HakonHarnes/img-clip.nvim",
            event = "VeryLazy",
            opts = {
                default = {
                    embed_image_as_base64 = true,
                    prompt_for_file_name = false,
                    drag_and_drop = {
                        insert_mode = true,
                    },
                    use_absolute_path = true,
                },
            },
        },
        {
            "MeanderingProgrammer/render-markdown.nvim",
            opts = {
                file_types = { "markdown", "Avante" },
                render_on_save = true,
                output_format = "html",
                output_dir = "~/Documents/markdown-output",
                open_browser_after_render = false,
            },
            ft = { "markdown", "Avante" },
        },
    },
}
