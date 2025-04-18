return {
  "vyfor/cord.nvim",
  lazy = false,
  config = function()
    local discord_config = require("config.discord")
    discord_config.setup_all()
  end,
}
