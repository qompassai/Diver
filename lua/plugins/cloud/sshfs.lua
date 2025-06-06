return {
  "nosduco/remote-sshfs.nvim",
  lazy = true,
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("telescope").load_extension("remote-sshfs")
  end,
  opts = {
    connections = {
      ssh_configs = {
        vim.fn.expand("$HOME/.ssh/config"),
        "/etc/ssh/ssh_config",
      },
      sshfs_args = {
        "-o",
        "reconnect",
        "-o",
        "ConnectTimeout=5",
      },
    },
    mounts = {
      base_dir = vim.fn.expand("$HOME/.sshfs/"),
      unmount_on_exit = true,
    },
    handlers = {
      on_connect = {
        change_dir = true,
      },
      on_disconnect = {
        clean_mount_folders = false,
      },
    },
    ui = {
      select_prompts = true,
      confirm = {
        connect = true,
        change_dir = false,
      },
    },
    log = {
      enable = true,
      truncate = false,
      types = {
        all = true,
        util = true,
        handler = true,
        sshfs = true,
      },
    },
  },
}
