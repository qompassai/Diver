return {
  {
    "mrjones2014/legendary.nvim",
    priority = 10000,
    lazy = false,
    dependencies = { "kkharji/sqlite.lua" },
  },
  {
    "folke/flash.nvim",
    keys = {
      {
        "s",
        function()
          require("flash").jump()
        end,
        mode = { "n", "x", "o" },
        desc = "Jump forwards",
      },
      {
        "S",
        function()
          require("flash").jump { search = { forward = false } }
        end,
        mode = { "n", "x", "o" },
        desc = "Jump backwards",
      },
    },
  },
}
