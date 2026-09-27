-- /qompassai/Diver/lua/utils/options/globals.lua
-- Qompass AI Diver Global Variables
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- Every `vim.g` variable init.lua used to set, in one alphabetical place.
---
--- Plain-language version: these are Neovim's global variables -- the
--- settings that plugins read (which leader key, which python, where the
--- XDG folders live). Same values and same conditionals as before, just
--- no longer scattered through init.lua.
---@module 'utils.options.globals'

local env = vim.env
local fn = vim.fn
local g = vim.g
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1

local M = {}

--- Apply every vim.g variable. Idempotent; runs early (phase 1) so
--- plugin managers and providers see leader keys and host programs
--- before they load.
function M.setup()
    -- Identity for the XDG paths below. vim.uv.os_get_passwd() reads the
    -- passwd entry without fork+exec (~880x faster than `id -u`/`whoami`).
    local user, uid
    if is_windows then
        user = env.USERNAME or env.USER
        uid = user
    else
        local passwd = vim.uv.os_get_passwd()
        uid = (passwd and tostring(passwd.uid)) or fn.system('id -u'):gsub('\n', '')
        user = env.USER or (passwd and passwd.username) or fn.system('whoami'):gsub('\n', '')
    end

    g.deprecation_warnings = true
    g.editorconfig = true
    g.git_command_ssh = 1
    g.guipty = true
    g.loaded_illuminate = true
    --g.loaded_netrw = 1
    g.loaded_netrwPlugin = 1
    g.loaded_node_provider = 1
    g.loaded_perl_provider = 1
    g.loaded_python_provider = 1
    g.loaded_ruby_provider = 1
    g.lsp_enable_on_demand = true
    g.mapleader = ' '
    g.maplocalleader = ' '
    g.mkdp_theme = 'dark'
    g.netrw_altfile = 1
    g.netrw_preview = 1
    if not is_windows then
        g.node_host_prog = 'node'
        g.perl_host_prog = 'perl'
        g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
        g.python3_host_prog = '/usr/bin/python3'
        g.ruby_host_prog = 'neovim-ruby-host'
    else
        g.python3_host_prog = 'python'
    end
    g.query_lint_on = {}
    g.rust_cargo_check_all_targets = true
    g.rust_cargo_check_benches = true
    g.rust_conceal = false
    g.rust_conceal_pub = false
    g.rust_playpen_url = 'https://play.rust-lang.org/'
    g.rust_recommended_style = true
    g.rustfmt_detect_version = false
    g.rustfmt_emit_files = false
    g.rust_shortener_url = 'https://is.gd/'
    g.ruff_makeprg_params = '--max-line-length --preview '
    g.semantic_tokens_enabled = true
    g.table_mode_always_active = 1
    g.table_mode_corner = '|'
    g.table_mode_separator = '|'
    g.table_mode_syntax = 1
    g.table_mode_update_time = 300
    g.use_blink_cmp = false
    g.vim_markdown_folding_disabled = 1
    g.vim_markdown_follow_anchor = 1
    g.vim_markdown_math = 1
    g.vim_markdown_frontmatter = 1
    g.vim_markdown_toml_frontmatter = 1
    g.vim_markdown_json_frontmatter = 1
    g.which_key_disable_health_check = 1
    g.xdg_bin_home = env.XDG_BIN_HOME
        or (is_windows and fn.expand('~/AppData/Local/Programs') or fn.expand('~/.local/bin'))
    g.xdg_cache_home = env.XDG_CACHE_HOME or (is_windows and fn.expand('~/AppData/Local/Temp') or fn.expand('~/.cache'))
    g.xdg_config_dirs = is_windows and ''
        or (env.XDG_CONFIG_DIRS or fn.expand('~/.config/xdg:/etc/xdg:/usr/local/etc/xdg:/usr/etc/xdg'))
    g.xdg_config_home = env.XDG_CONFIG_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.config'))
    if not is_windows then
        g.xdg_current_desktop = env.XDG_CURRENT_DESKTOP or 'Hyprland'
        g.xdg_current_session = env.XDG_CURRENT_SESSION or 'Hyprland'
    end
    g.xdg_data_dirs = is_windows and ''
        or (env.XDG_DATA_DIRS or fn.expand('~/.local/share:/usr/local/share:/usr/share'))
    g.xdg_data_home = env.XDG_DATA_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.local/share'))
    g.xdg_desktop_dir = env.XDG_DESKTOP_DIR or fn.expand(is_windows and '~/Desktop' or '~/.Desktop')
    if not is_windows then
        g.xdg_desktop_portal_dir = env.XDG_DESKTOP_PORTAL_DIR or ('/run/user/' .. uid .. '/xdg-desktop-portal/portals')
    end
    g.xdg_documents_dir = env.XDG_DOCUMENTS_DIR or fn.expand(is_windows and '~/Documents' or '~/.Documents')
    g.xdg_download_dir = env.XDG_DOWNLOAD_DIR or fn.expand(is_windows and '~/Downloads' or '~/.Downloads')
    if not is_windows then
        g.nix_per_user_profile = '/nix/var/nix/profiles/per-user/' .. user
    end
    g.xdg_state_home = env.XDG_STATE_HOME
        or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.local/state'))
    g.xdg_runtime_dir = env.XDG_RUNTIME_DIR
        or (is_windows and (env.TEMP or fn.expand('~/AppData/Local/Temp')) or ('/run/user/' .. uid))
    g.xdg_utils_debug_level = env.XDG_UTILS_DEBUG_LEVEL or 3
    if env.SSH_TTY then
        g.clipboard = 'osc52'
    end
    -- Moved up from the late block: guifont is only read by GUI frontends,
    -- nothing in the terminal/headless setup path consumes it.
    g.guifont = 'DaddyTimeMono Nerd Font Mono:h13'
end

return M
