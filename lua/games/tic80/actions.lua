-- #################################################################
-- /qompassai/Diver/lua/games/tic80/actions.lua
-- Qompass AI TIC-80 Actions
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
--- Action implementations for the verified TIC-80 CLI/console surface.
---
--- Verified upstream (wiki, 2026-09-28):
--- * Headless automation: `tic80 --cli --skip --fs <dir> --cmd "a & b & exit"`.
--- * `export [win|winxp|linux|rpi|mac|html|binary|tiles|sprites|map|mapimg|
---   sfx|music|screen|help] <outfile> [bank=0 vbank=0 id=0 alone=0]`.
--- * `import [binary|tiles|sprites|map|code|screen] <file> [bank=0 x=0 y=0
---   w=0 h=0 vbank=0]` (PNG for tiles/sprites; colors quantize to the
---   nearest palette color; files resolve against the `--fs` storage dir).
--- * `load <cart> [code|tiles|sprites|map|sfx|music|palette|flags|screen]`
---   moves sections cart-to-cart; `save <cart>` persists.
--- * In-game hotkeys: F1..F5 code/sprite/map/sfx/music editors, F7 assign
---   cover, F8 screenshot, F9 start/stop GIF recording.
---
--- Verified gaps (wired honestly, never faked):
--- * `import` has NO sfx/music target: music/SFX are composed in the
---   built-in tracker (F4/F5). `export music` writes WAV; `load` moves
---   music between carts. There is no external music import path.
--- * The CLI has NO screenshot/GIF flags: capture is F8/F9 in-game only.
--- * `export ... alone=1` (editor-stripped binaries) is PRO-only: never
---   passed here.
--- * TIC-80's console parser has no documented quoting: project paths with
---   spaces are refused rather than guessed at.
---@module 'games.tic80.actions'

local config = require('games.tic80.config')
local util = require('games.tic80.util')
local shared_util = require('games.shared.util')

local notify = vim.notify
local levels = vim.log.levels

local M = {}

---@type boolean
M.watch_enabled = true

---@type vim.SystemObj?
local current_job = nil
local SIGTERM = 'sigterm'
local STDERR_PREVIEW_MAX = 500

---Stop the running cart, if any. Idempotent: safe to call with no job.
local function stop_current()
    local job = current_job
    current_job = nil
    if job ~= nil then
        pcall(job.kill, job, SIGTERM)
    end
end

---@return string? `.tic` path: current buffer when it is a cart, else a prompt.
local function current_cart_or_prompt()
    local current = vim.api.nvim_buf_get_name(0)
    if current:sub(-4) == '.tic' then
        return current
    end
    local input = shared_util.trim(vim.fn.input('TIC-80 cart (.tic): ', '', 'file'))
    if input == '' then
        return nil
    end
    return vim.fn.expand(input)
end

---@param path string
---@return boolean true when the path contains no spaces.
local function assert_no_spaces(path)
    if path:find(' ', 1, true) ~= nil then
        notify(
            'TIC-80: paths with spaces are not supported by the TIC-80 console parser: ' .. path,
            levels.WARN
        )
        return false
    end
    return true
end

---@param workdir string `--fs` storage directory.
---@param chain string Console commands joined with ' & '.
---@return boolean ok False when the binary is missing or the chain failed.
local function run_console_chain(workdir, chain)
    local argv = util.console_argv(workdir, chain)
    if argv == nil then
        return false
    end
    local completed = vim.system(argv, { text = true }):wait()
    if completed.code ~= 0 then
        local stderr = shared_util.trim(completed.stderr or '')
        notify(
            'TIC-80: console chain failed: ' .. stderr:sub(1, STDERR_PREVIEW_MAX),
            levels.ERROR
        )
        return false
    end
    return true
end

---@param path string File to write.
---@param content string Full file content.
---@return boolean ok
local function write_file(path, content)
    local handle, err = io.open(path, 'w')
    if handle == nil then
        notify('TIC-80: cannot write ' .. path .. ': ' .. tostring(err), levels.ERROR)
        return false
    end
    handle:write(content)
    handle:close()
    return true
end

---Copy `file` into `workdir` when it lives elsewhere; `import` only sees
---the `--fs` storage dir. Returns the in-workdir basename, or nil on failure.
---@param file string Absolute source path.
---@param workdir string Absolute, normalized destination directory.
---@return string? basename
local function ensure_in_workdir(file, workdir)
    local dir = vim.fs.normalize(vim.fn.fnamemodify(file, ':h'))
    local base = vim.fn.fnamemodify(file, ':t')
    if dir == workdir then
        return base
    end
    local dest = workdir .. '/' .. base
    local ok, err = pcall(vim.uv.fs_copyfile, file, dest)
    if not ok then
        notify(
            'TIC-80: cannot stage ' .. file .. ' into ' .. workdir .. ': ' .. tostring(err),
            levels.ERROR
        )
        return nil
    end
    notify('TIC-80: staged ' .. base .. ' into the cart directory for import.', levels.INFO)
    return base
end

---@param cart string Absolute cart path.
---@return string dir, string base Cart directory and load-name (no extension).
local function cart_parts(cart)
    local dir = vim.fs.normalize(vim.fn.fnamemodify(cart, ':h'))
    local base = vim.fn.fnamemodify(cart, ':t:r')
    return dir, base
end

---Run a cart (.tic) or script (.lua), stopping the previous run first.
---@param file string Cart or script path to hand to tic80.
---@return boolean ok False when the path is empty or no binary is available.
function M.run_cart(file)
    if file == '' then
        notify('games.tic80: refusing to run an empty path', levels.WARN)
        return false
    end
    local bin = util.find_binary()
    if bin == nil then
        notify('games.tic80: no tic80 binary found (install tic80 / tic-80-bin)', levels.WARN)
        return false
    end
    stop_current()
    ---@type string[]
    local argv = { bin }
    for _, arg in ipairs(config.current.extra_args) do
        argv[#argv + 1] = arg
    end
    argv[#argv + 1] = file
    current_job = vim.system(argv)
    return true
end

---Stop the running cart, if any.
function M.stop_cart()
    stop_current()
end

---@return boolean enabled The watch state after toggling.
function M.toggle_watch()
    M.watch_enabled = not M.watch_enabled
    return M.watch_enabled
end

---Scaffold a new cart: project dir, `game.lua` stub, and a `shim.lua`
---whose single `dofile()` line becomes the cart's code section, so Lua
---stays editable in Neovim (free-build external-editor workflow).
function M.new_cart()
    local name = shared_util.trim(vim.fn.input('TIC-80 new cart name: ', 'game'))
    if name == '' then
        return
    end
    local dir = shared_util.trim(
        vim.fn.input('TIC-80 project dir: ', vim.fn.expand('~/tic80/') .. name, 'dir')
    )
    if dir == '' then
        return
    end
    dir = vim.fs.normalize(vim.fn.expand(dir))
    if not assert_no_spaces(dir) then
        return
    end
    vim.fn.mkdir(dir, 'p')

    local game_path = dir .. '/game.lua'
    if vim.fn.filereadable(game_path) == 0 then
        local stub = table.concat({
            '-- title: ' .. name,
            '-- author: Matt',
            '-- script: lua',
            '',
            'function TIC()',
            '  -- your game here',
            'end',
            '',
        }, '\n')
        if not write_file(game_path, stub) then
            return
        end
    end

    local shim = table.concat({
        '-- TIC-80 free-build shim: code lives in game.lua, edited in Neovim.',
        'dofile(\'' .. dir .. '/game.lua\')',
        '',
    }, '\n')
    if not write_file(dir .. '/shim.lua', shim) then
        return
    end

    if run_console_chain(dir, 'new lua & import code shim.lua & save game.tic & exit') then
        notify(
            'TIC-80: cart scaffolded at ' .. dir .. '/game.tic (code shims to game.lua).',
            levels.INFO
        )
    end
end

---Export the cart as a build: `export <fmt> <outfile>` over a `vim.ui.select`
---of the wiki-verified formats. `alone=1` is PRO-only and never passed.
function M.export_build()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    vim.ui.select(config.build_formats, {
        prompt = 'TIC-80 export format:',
    }, function(fmt)
        if fmt == nil then
            return
        end
        local dir, base = cart_parts(cart)
        local out = shared_util.trim(
            vim.fn.input('TIC-80 export name (no extension): ', dir .. '/' .. base .. '-' .. fmt)
        )
        if out == '' then
            return
        end
        if not assert_no_spaces(out) then
            return
        end
        local chain = 'load ' .. base .. ' & export ' .. fmt .. ' ' .. out .. ' & exit'
        if run_console_chain(dir, chain) then
            notify('TIC-80: exported ' .. fmt .. ' -> ' .. out, levels.INFO)
        end
    end)
end

---Export cart media: sprites/tiles/map as PNG, map as .map, cover as PNG,
---sfx/music as WAV (with `id=`), help as markdown.
function M.export_media()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    vim.ui.select(config.media_targets, {
        prompt = 'TIC-80 media to export:',
        format_item = function(target)
            return target.kind .. ' (' .. target.extension .. ')'
        end,
    }, function(target)
        if target == nil then
            return
        end
        ---@cast target games.tic80.MediaTarget
        local dir, base = cart_parts(cart)
        local out = shared_util.trim(
            vim.fn.input(
                'TIC-80 export name (no extension): ',
                dir .. '/' .. base .. '-' .. target.kind
            )
        )
        if out == '' then
            return
        end
        if not assert_no_spaces(out) then
            return
        end
        local chain = 'load ' .. base .. ' & export ' .. target.kind .. ' ' .. out
        if target.needs_id then
            local id = shared_util.trim(vim.fn.input('TIC-80 ' .. target.kind .. ' id: ', '0'))
            if id == '' then
                return
            end
            chain = chain .. ' id=' .. id
        end
        if run_console_chain(dir, chain .. ' & exit') then
            notify(
                'TIC-80: exported ' .. target.kind .. ' -> ' .. out .. target.extension,
                levels.INFO
            )
        end
    end)
end

---Import an asset file into the cart: `import <kind> <file>`.
---PNG is the verified format for sprites/tiles; imported colors quantize
---to the nearest palette color.
function M.import_asset()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    vim.ui.select(config.import_kinds, {
        prompt = 'TIC-80 asset kind to import:',
    }, function(kind)
        if kind == nil then
            return
        end
        local file = shared_util.trim(
            vim.fn.input('TIC-80 file to import as ' .. kind .. ': ', '', 'file')
        )
        if file == '' then
            return
        end
        file = vim.fs.normalize(vim.fn.expand(file))
        local dir, base = cart_parts(cart)
        local staged = ensure_in_workdir(file, dir)
        if staged == nil then
            return
        end
        local chain = 'load '
            .. base
            .. ' & import '
            .. kind
            .. ' '
            .. staged
            .. ' & save '
            .. base
            .. ' & exit'
        if run_console_chain(dir, chain) then
            notify(
                'TIC-80: imported ' .. kind .. ' from ' .. staged .. ' into ' .. base .. '.tic',
                levels.INFO
            )
        end
    end)
end

---Voidsprite bridge: import a PNG sprite sheet (drawn in voidsprite) into
---the cart's sprite memory. Stages the PNG into the cart dir because
---`import` resolves against the `--fs` storage dir.
function M.import_spritesheet()
    local current = vim.api.nvim_buf_get_name(0)
    local initial = current:sub(-4) == '.png' and current or ''
    local file = shared_util.trim(
        vim.fn.input('TIC-80 sprite sheet PNG (from voidsprite): ', initial, 'file')
    )
    if file == '' then
        return
    end
    file = vim.fs.normalize(vim.fn.expand(file))
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    local dir, base = cart_parts(cart)
    local staged = ensure_in_workdir(file, dir)
    if staged == nil then
        return
    end
    local chain = 'load '
        .. base
        .. ' & import sprites '
        .. staged
        .. ' & save '
        .. base
        .. ' & exit'
    if run_console_chain(dir, chain) then
        notify(
            'TIC-80: sprite sheet imported; colors were quantized to the nearest palette color.',
            levels.INFO
        )
    end
end

---Launch the cart in the TIC-80 GUI for the built-in editors. There is no
---console command that opens an editor; the in-app hotkeys are F1..F5.
function M.open_editors()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    local bin = util.require_binary()
    if bin == nil then
        return
    end
    vim.fn.jobstart({ bin, cart }, { detach = true })
    notify(
        'TIC-80: editors open on '
            .. vim.fs.basename(cart)
            .. ' (F1 code - F2 sprites - F3 map - F4 sfx - F5 music).',
        levels.INFO
    )
end

---Run the cart and report the capture hotkeys. TIC-80 exposes no CLI
---screenshot/GIF flags: capture is F8 (screenshot) / F9 (GIF) in-game only.
function M.capture_media()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    if M.run_cart(cart) then
        notify(
            'TIC-80: in the running game, F8 takes a screenshot and F9 starts/stops GIF recording.',
            levels.INFO
        )
    end
end

---Export one music track to WAV. Music has no external import path
---(`import` accepts no sfx/music target): composition happens in the
---tracker (F5); this action only renders tracks out.
function M.export_music_track()
    local cart = current_cart_or_prompt()
    if cart == nil then
        return
    end
    local id = shared_util.trim(vim.fn.input('TIC-80 music track id: ', '0'))
    if id == '' then
        return
    end
    local dir, base = cart_parts(cart)
    local out = shared_util.trim(
        vim.fn.input('TIC-80 WAV name (no extension): ', dir .. '/' .. base .. '-track' .. id)
    )
    if out == '' then
        return
    end
    if not assert_no_spaces(out) then
        return
    end
    local chain = 'load ' .. base .. ' & export music ' .. out .. ' id=' .. id .. ' & exit'
    if run_console_chain(dir, chain) then
        notify('TIC-80: exported music track ' .. id .. ' -> ' .. out .. '.wav', levels.INFO)
    end
end

function M.describe_environment()
    notify(table.concat({
        'TIC-80 binary: ' .. (util.find_binary() or 'not found'),
        'TIC-80 version: ' .. (util.version() or 'unknown'),
        'Watched dirs: ' .. table.concat(config.current.dirs, ', '),
        'Auto-restart on save: ' .. tostring(M.watch_enabled and config.current.auto_restart),
    }, '\n'), levels.INFO)
end

---@return table[]
local function run_actions()
    return {
        {
            id = 'run_cart',
            label = 'Run cart or script',
            group = 'Run',
            run = function()
                local target = vim.api.nvim_buf_get_name(0)
                M.run_cart(target)
            end,
        },
        { id = 'stop_cart', label = 'Stop running cart', group = 'Run', run = M.stop_cart },
        {
            id = 'toggle_watch',
            label = 'Toggle auto-restart on save',
            group = 'Run',
            run = function()
                local enabled = M.toggle_watch()
                notify(
                    'games.tic80: auto-restart on save ' .. (enabled and 'enabled' or 'disabled'),
                    levels.INFO
                )
            end,
        },
    }
end

---@return table[]
local function cart_actions()
    return {
        {
            id = 'new_cart',
            label = 'New cart (dofile shim scaffold)',
            group = 'Cart',
            run = M.new_cart,
        },
        {
            id = 'describe_environment',
            label = 'Describe environment',
            group = 'Cart',
            run = M.describe_environment,
        },
    }
end

---@return table[]
local function export_actions()
    return {
        {
            id = 'export_build',
            label = 'Export build (html/binary/native)',
            group = 'Export',
            run = M.export_build,
        },
        {
            id = 'export_media',
            label = 'Export media (sprites/map/sfx/music/cover)',
            group = 'Export',
            run = M.export_media,
        },
    }
end

---@return table[]
local function music_actions()
    return {
        {
            id = 'export_music_track',
            label = 'Export music track to WAV',
            group = 'Music',
            run = M.export_music_track,
        },
    }
end

---@return table[]
local function import_actions()
    return {
        {
            id = 'import_spritesheet',
            label = 'Import PNG sprite sheet (voidsprite bridge)',
            group = 'Import',
            run = M.import_spritesheet,
        },
        {
            id = 'import_asset',
            label = 'Import asset (tiles/map/code/cover)',
            group = 'Import',
            run = M.import_asset,
        },
    }
end

---@return table[]
local function editor_actions()
    return {
        {
            id = 'open_editors',
            label = 'Open built-in editors (F1-F5)',
            group = 'Editors',
            run = M.open_editors,
        },
        {
            id = 'capture_media',
            label = 'Run + capture (F8 screenshot / F9 GIF)',
            group = 'Editors',
            run = M.capture_media,
        },
    }
end

---@return table[] Action descriptors for the menu/command surface.
function M.get_actions()
    local result = {}
    vim.list_extend(result, run_actions())
    vim.list_extend(result, cart_actions())
    vim.list_extend(result, export_actions())
    vim.list_extend(result, music_actions())
    vim.list_extend(result, import_actions())
    vim.list_extend(result, editor_actions())
    return result
end

---@param action table Action descriptor from get_actions().
function M.run_action(action)
    action.run()
end

---@param id string Action id from get_actions().
function M.run_action_by_id(id)
    local map = shared_util.build_action_map(M.get_actions())
    local action = map[id]
    if action == nil then
        notify('Unknown TIC-80 action: ' .. id, levels.ERROR)
        return
    end
    M.run_action(action)
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        group_order = config.group_order,
        prompt = 'Select TIC-80 action:',
    })
end

return M
