#!/usr/bin/env lua5.1

-- /qompassai/Diver/lua/utils/options/global.lua
-- Qompass AI Neovim Global Options
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local o = vim.o
local env = vim.env
local go = vim.go
local g = vim.g
local fn = vim.fn
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1
local opt = vim.opt
function M.setup()
    g.deprecation_warnings = true
    g.editorconfig = true
    g.git_command_ssh = 1
    g.guipty = true
    g.loaded_illuminate = true
    g.loaded_netrw = 1
    g.loaded_netrwPlugin = 1
    g.loaded_node_provider = 1
    g.loaded_perl_provider = 1
    g.loaded_python_provider = 1
    g.loaded_ruby_provider = 1
    g.lsp_enable_on_demand = true
    g.mapleader = ' '
    g.maplocalleader = '\\'
    g.mkdp_markdown_css = (
        env.XDG_CONFIG_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.config'))
    ) .. '/nvim/markdown.css' ---@type string
    g.mkdp_theme = 'dark'
    g.netrw_altfile = 1
    g.netrw_preview = 1
    g.node_host_prog = '/usr/bin/node'
    g.perl_host_prog = '/usr/bin/perl'
    g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
    g.python3_host_prog = '/usr/bin/python3'
    g.ruby_host_prog = '/usr/bin/neovim-ruby-host'
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
g.use_blink_cmp = true
g.vim_markdown_folding_disabled = 1
g.vim_markdown_follow_anchor = 1
g.vim_markdown_math = 1
g.vim_markdown_frontmatter = 1
g.vim_markdown_toml_frontmatter = 1
g.vim_markdown_json_frontmatter = 1
g.which_key_disable_health_check = 1
--g.xdg_bin_home = env.XDG_BIN_HOME or (is_windows and fn.expand('~/AppData/Local/Programs') or fn.expand('~/.local/bin'))
--g.xdg_cache_home = env.XDG_CACHE_HOME or (is_windows and fn.expand('~/AppData/Local/Temp') or fn.expand('~/.cache'))
--g.xdg_config_dirs = is_windows and ''
--    or (env.XDG_CONFIG_DIRS or fn.expand('~/.config/xdg:/etc/xdg:/usr/local/etc/xdg:/usr/etc/xdg'))
--g.xdg_config_home = env.XDG_CONFIG_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.config'))
--if not is_windows then
--    g.xdg_current_desktop = env.XDG_CURRENT_DESKTOP or 'Hyprland'
--    g.xdg_current_session = env.XDG_CURRENT_SESSION or 'Hyprland'
--end
--g.xdg_data_dirs = is_windows and '' or (env.XDG_DATA_DIRS or fn.expand('~/.local/share:/usr/local/share:/usr/share'))
--g.xdg_data_home = env.XDG_DATA_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.local/share'))
--g.xdg_desktop_dir = env.XDG_DESKTOP_DIR or fn.expand(is_windows and '~/Desktop' or '~/.Desktop')

--if not is_windows then
--    g.xdg_desktop_portal_dir = env.XDG_DESKTOP_PORTAL_DIR or ('/run/user/' .. uid .. '/xdg-desktop-portal/portals')
--end
--g.xdg_documents_dir = env.XDG_DOCUMENTS_DIR or fn.expand(is_windows and '~/Documents' or '~/.Documents')
--g.xdg_download_dir = env.XDG_DOWNLOAD_DIR or fn.expand(is_windows and '~/Downloads' or '~/.Downloads')
--if not is_windows then
--    g.nix_per_user_profile = '/nix/var/nix/profiles/per-user/' .. user
--end
--g.xdg_state_home = env.XDG_STATE_HOME or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.local/state'))
--g.xdg_runtime_dir = env.XDG_RUNTIME_DIR
--    or (is_windows and (env.TEMP or fn.expand('~/AppData/Local/Temp')) or ('/run/user/' .. uid))
--g.xdg_utils_debug_level = env.XDG_UTILS_DEBUG_LEVEL or 3
--if env.SSH_TTY then
g.clipboard = 'osc52'
--end
--if not is_windows then
--    env.MOJO_STDLIB_PATH = fn.expand('~/.local/share/mojo/.pixi/envs/default/lib/mojo')
--else
--    env.MOJO_STDLIB_PATH = fn.expand('~/AppData/Local/mojo/.pixi/envs/default/lib/mojo')
--end
go.expandtab = true
o.allowrevins = true
o.ambiwidth = 'single'
o.autochdir = true
o.autocompletetimeout = 80
o.autocompletedelay = 0
o.autowrite = true
o.autowriteall = true
o.backup = false
o.background = 'dark'
o.backspace = 'indent,eol,start'
o.clipboard = 'unnamedplus'
o.cmdheight = 1
o.completeitemalign = 'abbr,kind,menu'
o.confirm = true
o.debug = 'msg'
o.diffopt = 'internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60'
o.encoding = 'utf-8'
o.errorbells = false
o.exrc = true
o.fileencodings = 'utf-8,ucs-bom,default,latin1'
o.fileformats = 'unix,dos,mac'
o.formatoptions = 'tcqj'
o.guicursor = 'n-v-c:block-Cursor/lCursor,i-ci-ve:ver25-Cursor/lCursor,r-cr-o:hor20-Cursor/lCursor'
g.guifont = 'DaddyTimeMono Nerd Font Mono:h13'
o.hidden = true
o.history = 1000
o.hlsearch = true
o.icon = false
o.ignorecase = true
o.inccommand = 'split'
o.incsearch = true
o.isprint = '@,161-255'
o.joinspaces = true
o.jumpoptions = 'clean'
o.langnoremap = true
o.langremap = false
o.laststatus = 3
o.lazyredraw = true
o.linespace = 0
o.magic = true
o.mat = 2
o.maxsearchcount = 999
o.modelines = 5
o.mouse = 'a'
o.mousescroll = 'ver:3,hor:6'
o.pumheight = 15
o.redrawtime = 10000
o.report = 9999
o.ruler = true
o.secure = true
o.sessionoptions = 'curdir,folds,help,tabpages,terminal,winsize'
o.shellslash = true
o.shortmess = 'IF'
o.showmode = false
o.showtabline = 2
o.sidescroll = 1
o.smartcase = true
o.smarttab = true
o.splitbelow = true
o.splitright = true
o.startofline = false
o.switchbuf = 'uselast'
o.tabpagemax = 50
o.timeout = true
o.timeoutlen = 300
o.title = true
o.ttimeoutlen = 10
o.ttyfast = true
o.undodir = fn.stdpath('data') .. '/undo'
o.updatetime = 50
o.viewoptions = 'unix,slash'
o.wildignore = '*.a'
o.wildignorecase = true
o.wildmenu = true
o.wildmode = 'noselect'
o.winborder = 'rounded'
o.wrap = false
o.writebackup = true
opt.comments:append('fb:•')
opt.complete:remove('i')
o.tags = './tags;,tags'
opt.viminfo:append('!')
opt.winblend = 40
opt.pumblend = 40
--end

return M