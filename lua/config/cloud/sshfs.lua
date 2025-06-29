-- /qompassai/Diver/lua/config/cloud/sshfs.lua
-- Qompass AI Diver SSHFS Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
M.opts = {
    connections = {
        ssh_configs = {
            vim.fn.expand('$HOME/.ssh/config'), '/etc/ssh/ssh_config'
        },
        sshfs_args = {'-o', 'reconnect', '-o', 'ConnectTimeout=5'}
    },
    mounts = {base_dir = vim.fn.expand('$HOME/.sshfs/'), unmount_on_exit = true},
    handlers = {
        on_connect = {change_dir = true},
        on_disconnect = {clean_mount_folders = false}
    },
    ui = {select_prompts = true, confirm = {connect = true, change_dir = false}},
    log = {
        enable = true,
        truncate = false,
        types = {all = true, util = true, handler = true, sshfs = true}
    }
}
return M
