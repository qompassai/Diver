-- plugins/core/trouble.lua
return {
  {
    'folke/trouble.nvim',
    cmd = { "TroubleToggle", "Trouble" },
    opts = {
      position = "bottom",
      height = 10,
      auto_open = false,
      auto_close = true,
      use_diagnostic_signs = true,
    },
    config = function(_, opts)
      require('trouble').setup(opts)
    end
  }
}
