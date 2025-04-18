return {
  "dgrbrady/nvim-docker",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  cmd = {
    "ContainerList",
    "ContainerLogs",
    "ContainerExec",
    "ContainerStart",
    "ContainerStop",
    "ContainerKill",
    "ContainerInspect",
    "ContainerRemove",
    "ContainerPrune",
    "ImageList",
    "ImagePull",
    "ImageRemove",
    "ImagePrune",
  },
  config = function()
    require("nvim-docker").setup({})
  end,
}
