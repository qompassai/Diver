return
{
    "lewis6991/gitsigns.nvim",
    lazy = true,
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
        return require("configs.gitsigns").opts
    end,
}

