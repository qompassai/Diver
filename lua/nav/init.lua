-- /qompassai/Diver/lua/nav/init.lua
-- Qompass AI Diver Directory Ring (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- In-editor directory ring mirroring the bash semantics of
-- ~/workspace/repos/dotfiles/.config/bash.d/cycled.bash:
-- swd (save/push)  -> :DirPush [dir]
-- cwd (next)       -> :DirNext
-- Cwd (prev)       -> :DirPrev
-- zwd (reset)      -> :DirReset
-- The ring is an ordered list with a current index; push dedupes and
-- is bounded by ring_size_max; next/prev wrap around and change the
-- working directory per cd_scope. Requiring this module registers
-- nothing and performs no I/O; M.setup() creates the user commands
-- and leader keymaps and, only when persist_enabled, restores the
-- ring from disk. There is no upstream release feed: this is Matt's
-- own module, so :NavUpdateCheck validates the persisted ring format
-- version locally instead of phoning home.
---@module 'nav'

local M = {}

local api = vim.api

---Current persisted ring format version.
M.RING_FORMAT_VERSION = '1.0.0'

local DIR_PATH_BYTES_MAX = 4096 -- longest accepted directory path.
local RING_FILE_SIZE_BYTES_MAX = 65536 -- largest ring.json we will decode.
local RING_SIZE_LIMIT_MAX = 256 -- hard ceiling on ring_size_max.
local FLOAT_WIDTH_MAX = 88 -- docs float width cap.
local FLOAT_HEIGHT_MAX = 40 -- docs float height cap.
local OUTPUT_LINES_MAX = 64 -- docs float body line cap.

M.default_config = {
    -- 'global' uses :cd, 'window' uses :lcd. Never touches other windows/tabs.
    cd_scope = 'global',
    -- Set the leader keymaps on setup.
    keymaps_enabled = true,
    -- Leader key for :DirNext.
    leader_next = '<leader>dn',
    -- Leader key for :DirPrev (dp is taken by DAP's Debug: Pause).
    leader_prev = '<leader>dP',
    -- Serialize the ring to stdpath('data')/nav/ring.json; restore on setup.
    persist_enabled = false,
    -- Prompt shown by the :DirList picker.
    picker_prompt = 'Directory ring:',
    -- Ring file name under stdpath('data')/nav/.
    ring_file_name = 'ring.json',
    -- Expected persisted ring format version (mirrors RING_FORMAT_VERSION).
    ring_format_version = '1.0.0',
    -- Maximum ring entries; push drops the oldest when exceeded.
    ring_size_max = 32,
    -- vim.ui.select-compatible picker; override in tests.
    select_impl = vim.ui.select,
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Type-check one config option. Programmer errors raise; expected
---absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= expected then
        error(('nav: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('cd_scope', merged.cd_scope, 'string')
    check_type('keymaps_enabled', merged.keymaps_enabled, 'boolean')
    check_type('leader_next', merged.leader_next, 'string')
    check_type('leader_prev', merged.leader_prev, 'string')
    check_type('persist_enabled', merged.persist_enabled, 'boolean')
    check_type('picker_prompt', merged.picker_prompt, 'string')
    check_type('ring_file_name', merged.ring_file_name, 'string')
    check_type('ring_format_version', merged.ring_format_version, 'string')
    check_type('ring_size_max', merged.ring_size_max, 'number')
    check_type('select_impl', merged.select_impl, 'function')
    if merged.cd_scope ~= 'global' and merged.cd_scope ~= 'window' then
        error('nav: cd_scope must be "global" or "window"', 2)
    end
    if merged.ring_size_max < 1 or merged.ring_size_max > RING_SIZE_LIMIT_MAX then
        error(('nav: ring_size_max must be 1..%d'):format(RING_SIZE_LIMIT_MAX), 2)
    end
    return merged
end

-- Ring state: ordered dirs, 1-based current index, 0 when empty.
local ring_dirs = {} ---@type string[]
local ring_index = 0 ---@type integer
local setup_done = false

---@type utils.toolmgr.Migration[]
local MIGRATIONS_NAV = {
    {
        version = '1.0.0',
        description = 'wrap a legacy version-less ring file (bare directory array) into { version, dirs }',
        apply = function()
            return M.migrate_legacy_ring()
        end,
    },
    {
        version = '2.0.0',
        description = '[template] placeholder for the next ring format; no-op until a real 2.0.0 shape is defined',
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---Whether path names an existing directory.
---@param path string
---@return boolean
local function is_directory(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == 'directory'
end

---Normalize a candidate dir: trim, reject empties and overlong paths,
---drop trailing slashes (root keeps its own).
---@param dir any
---@return string|nil clean
---@return string|nil err
local function clean_dir(dir)
    if type(dir) ~= 'string' then
        return nil, 'directory must be a string'
    end
    local trimmed = vim.trim(dir)
    if trimmed == '' then
        return nil, 'directory must not be blank'
    end
    if #trimmed > DIR_PATH_BYTES_MAX then
        return nil, 'directory path exceeds ' .. DIR_PATH_BYTES_MAX .. ' bytes'
    end
    local stripped = trimmed:gsub('/+$', '')
    if stripped == '' then
        stripped = '/'
    end
    return stripped, nil
end

---Position of dir in the ring, or nil.
---@param dir string
---@return integer|nil
local function find_entry(dir)
    for index, entry in ipairs(ring_dirs) do
        if entry == dir then
            return index
        end
    end
    return nil
end

---Change the working directory per cd_scope. Never touches windows or
---tabs other than the current one.
---@param dir string Existing directory.
---@return boolean ok
---@return string|nil err
local function change_directory(dir)
    local cmd = M.config.cd_scope == 'window' and 'lcd' or 'cd'
    local ok, cmd_err = pcall(vim.cmd, { cmd = cmd, args = { dir } })
    if not ok then
        return false, tostring(cmd_err)
    end
    return true, nil
end

---Persist after a mutation when enabled. Warns instead of failing the
---mutation: a lost persist must not undo a ring change.
local function persist_quiet()
    if not M.config.persist_enabled then
        return
    end
    local ok, err = M.save_ring()
    if not ok then
        vim.notify('nav: could not persist ring: ' .. tostring(err), vim.log.levels.WARN)
    end
end

---Notify a command failure in one canonical shape.
---@param what string Command name for the message.
---@param err any Failure reason.
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
end

---Push dir onto the ring (swd semantics). Validates the directory
---exists, dedupes (an existing entry becomes current instead of a
---duplicate), and drops the oldest entry past ring_size_max. The
---pushed directory becomes current.
---@param dir string Directory to push.
---@return boolean ok
---@return string|nil err
function M.push(dir)
    local clean, clean_err = clean_dir(dir)
    if clean_err ~= nil then
        return false, clean_err
    end
    assert(clean ~= nil, 'clean_dir returned no error but no path')
    if not is_directory(clean) then
        return false, 'not a directory: ' .. clean
    end
    local existing = find_entry(clean)
    if existing ~= nil then
        ring_index = existing
        persist_quiet()
        return true, nil
    end
    ring_dirs[#ring_dirs + 1] = clean
    while #ring_dirs > M.config.ring_size_max do
        table.remove(ring_dirs, 1)
    end
    ring_index = #ring_dirs
    persist_quiet()
    return true, nil
end

---Cycle forward with wraparound (cwd semantics) and change to it.
---@return string|nil dir
---@return string|nil err
function M.next()
    if #ring_dirs == 0 then
        return nil, 'ring is empty'
    end
    ring_index = ring_index % #ring_dirs + 1
    local dir = ring_dirs[ring_index]
    local ok, err = change_directory(dir)
    if not ok then
        return nil, err
    end
    persist_quiet()
    return dir, nil
end

---Cycle backward with wraparound (Cwd semantics) and change to it.
---@return string|nil dir
---@return string|nil err
function M.prev()
    if #ring_dirs == 0 then
        return nil, 'ring is empty'
    end
    ring_index = (ring_index - 2) % #ring_dirs + 1
    local dir = ring_dirs[ring_index]
    local ok, err = change_directory(dir)
    if not ok then
        return nil, err
    end
    persist_quiet()
    return dir, nil
end

---Clear the ring (zwd semantics).
---@return boolean ok
function M.reset()
    ring_dirs = {}
    ring_index = 0
    persist_quiet()
    return true
end

---Jump to the entry at index and change to it.
---@param index integer 1-based ring position.
---@return string|nil dir
---@return string|nil err
function M.jump(index)
    if type(index) ~= 'number' or index ~= math.floor(index) then
        return nil, 'index must be an integer'
    end
    if index < 1 or index > #ring_dirs then
        return nil, ('index %d out of range (ring holds %d)'):format(index, #ring_dirs)
    end
    ring_index = index
    local dir = ring_dirs[ring_index]
    local ok, err = change_directory(dir)
    if not ok then
        return nil, err
    end
    persist_quiet()
    return dir, nil
end

---Copy of the ring entries in order.
---@return string[] dirs
function M.entries()
    local copy = {}
    for index, dir in ipairs(ring_dirs) do
        copy[index] = dir
    end
    return copy
end

---Current ring entry, or nil when the ring is empty.
---@return string|nil dir
function M.current()
    if ring_index < 1 or ring_index > #ring_dirs then
        return nil
    end
    return ring_dirs[ring_index]
end

---Current 1-based index, 0 when the ring is empty.
---@return integer
function M.current_index()
    return ring_index
end

---Number of ring entries.
---@return integer
function M.size()
    return #ring_dirs
end

---Absolute path of the persisted ring file.
---@return string path
function M.ring_path()
    return vim.fs.joinpath(vim.fn.stdpath('data'), 'nav', M.config.ring_file_name)
end

---Serialize the ring atomically (tmp + rename), bounded by
---ring_size_max. The payload is { version, dirs } JSON.
---@return boolean ok
---@return string|nil err
function M.save_ring()
    if not M.config.persist_enabled then
        return false, 'persistence is disabled'
    end
    local path = M.ring_path()
    local dir = vim.fs.dirname(path)
    if vim.fn.mkdir(dir, 'p') ~= 1 and vim.fn.isdirectory(dir) ~= 1 then
        return false, 'cannot create nav data dir: ' .. dir
    end
    local payload = { version = M.config.ring_format_version, dirs = M.entries() }
    local ok, text = pcall(vim.json.encode, payload)
    if not ok or type(text) ~= 'string' then
        return false, 'cannot encode ring'
    end
    local tmp = path .. '.tmp'
    local file, file_err = io.open(tmp, 'w')
    if file == nil then
        return false, 'cannot write ring: ' .. tostring(file_err)
    end
    file:write(text)
    file:close()
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        return false, 'cannot replace ring file: ' .. tostring(rename_err)
    end
    return true, nil
end

---Validate one decoded ring entry.
---@param raw any
---@return string|nil dir
local function parse_ring_entry(raw)
    if type(raw) ~= 'string' or raw == '' then
        return nil
    end
    return raw
end

---Restore the ring from disk when persist_enabled. Malformed entries
---are dropped; a missing file is an empty ring, not an error.
---@return boolean ok
---@return integer|string count_or_err
function M.restore_ring()
    if not M.config.persist_enabled then
        return false, 'persistence is disabled'
    end
    local path = M.ring_path()
    if vim.fn.filereadable(path) ~= 1 then
        return true, 0
    end
    if vim.fn.getfsize(path) > RING_FILE_SIZE_BYTES_MAX then
        return false, 'ring file exceeds ' .. RING_FILE_SIZE_BYTES_MAX .. ' bytes'
    end
    local file, file_err = io.open(path, 'r')
    if file == nil then
        return false, 'cannot read ring file: ' .. tostring(file_err)
    end
    local text = file:read('*a')
    file:close()
    if text == nil or vim.trim(text) == '' then
        return false, 'ring file is empty'
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return false, 'ring file is not valid JSON'
    end
    local raw_dirs = decoded.dirs
    if type(raw_dirs) ~= 'table' then
        return false, 'ring file has no dirs array'
    end
    local restored = {}
    local dropped = 0
    for _, raw in ipairs(raw_dirs) do
        if #restored >= M.config.ring_size_max then
            break
        end
        local dir = parse_ring_entry(raw)
        if dir ~= nil then
            restored[#restored + 1] = dir
        else
            dropped = dropped + 1
        end
    end
    ring_dirs = restored
    ring_index = #restored > 0 and 1 or 0
    if dropped > 0 then
        vim.notify(('nav: dropped %d malformed ring entries'):format(dropped), vim.log.levels.WARN)
    end
    return true, #restored
end

---Format version recorded in the persisted ring file. Legacy files
---(bare directory array, no version field) report '0.0.0'.
---@return string|nil version
---@return string|nil err
function M.ring_file_version()
    local path = M.ring_path()
    if vim.fn.filereadable(path) ~= 1 then
        return nil, 'no persisted ring file'
    end
    local file, file_err = io.open(path, 'r')
    if file == nil then
        return nil, 'cannot read ring file: ' .. tostring(file_err)
    end
    local text = file:read('*a')
    file:close()
    if text == nil or vim.trim(text) == '' then
        return nil, 'ring file is empty'
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'ring file is not valid JSON'
    end
    if decoded.version == nil then
        return '0.0.0', nil
    end
    if type(decoded.version) ~= 'string' then
        return nil, 'ring file has a malformed version field'
    end
    return decoded.version, nil
end

---Migration 1.0.0: rewrite a legacy version-less ring file (bare
---directory array) into the versioned { version, dirs } shape.
---@return boolean ok
---@return string note
function M.migrate_legacy_ring()
    local path = M.ring_path()
    local file = io.open(path, 'r')
    if file == nil then
        return true, 'no legacy ring file to migrate'
    end
    local text = file:read('*a')
    file:close()
    if text == nil or vim.trim(text) == '' then
        return true, 'legacy ring file is empty; nothing to migrate'
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or type(decoded) ~= 'table' or decoded.version ~= nil then
        return true, 'no legacy shape found; nothing to migrate'
    end
    local dirs = {}
    for _, raw in ipairs(decoded) do
        local dir = parse_ring_entry(raw)
        if dir ~= nil then
            dirs[#dirs + 1] = dir
        end
    end
    local payload = { version = M.RING_FORMAT_VERSION, dirs = dirs }
    local enc_ok, encoded = pcall(vim.json.encode, payload)
    if not enc_ok or type(encoded) ~= 'string' then
        return false, 'cannot encode migrated ring'
    end
    local tmp = path .. '.tmp'
    local out, out_err = io.open(tmp, 'w')
    if out == nil then
        return false, 'cannot write migrated ring: ' .. tostring(out_err)
    end
    out:write(encoded)
    out:close()
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        return false, 'cannot replace ring file: ' .. tostring(rename_err)
    end
    return true, ('migrated %d legacy entries to format %s'):format(#dirs, M.RING_FORMAT_VERSION)
end

---Open a centered, minimal float. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
local function open_float(lines, title)
    local buf = api.nvim_create_buf(false, true)
    local shown = {}
    for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
        shown[#shown + 1] = lines[index]
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, shown)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'diver-nav'
    local win_width = math.min(FLOAT_WIDTH_MAX, vim.o.columns - 4)
    local win_height = math.min(math.max(#shown + 2, 8), math.min(FLOAT_HEIGHT_MAX, vim.o.lines - 4))
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = math.floor((vim.o.lines - win_height) / 2),
        col = math.floor((vim.o.columns - win_width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close nav float' })
end

---:DirPush [dir] -- push dir (default: cwd) onto the ring.
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_push(cmd_opts)
    local target = vim.trim(cmd_opts.args or '')
    if target == '' then
        target = vim.fn.getcwd()
    end
    local ok, err = M.push(target)
    if not ok then
        notify_failed('DirPush', err)
        return
    end
    vim.notify('nav: pushed ' .. target .. ' (' .. M.size() .. ' in ring)', vim.log.levels.INFO)
end

---:DirNext -- cycle forward.
local function cmd_next()
    local dir, err = M.next()
    if err ~= nil then
        vim.notify('DirNext: ' .. err, vim.log.levels.WARN)
        return
    end
    vim.notify('nav: ' .. tostring(dir), vim.log.levels.INFO)
end

---:DirPrev -- cycle backward.
local function cmd_prev()
    local dir, err = M.prev()
    if err ~= nil then
        vim.notify('DirPrev: ' .. err, vim.log.levels.WARN)
        return
    end
    vim.notify('nav: ' .. tostring(dir), vim.log.levels.INFO)
end

---:DirReset -- clear the ring.
local function cmd_reset()
    M.reset()
    vim.notify('nav: ring cleared', vim.log.levels.INFO)
end

---:DirList -- pick a ring entry with the configured picker and jump to it.
local function cmd_list()
    local dirs = M.entries()
    if #dirs == 0 then
        vim.notify('DirList: ring is empty', vim.log.levels.INFO)
        return
    end
    local items = {}
    for index, dir in ipairs(dirs) do
        local marker = index == ring_index and '> ' or '  '
        items[index] = marker .. dir
    end
    M.config.select_impl(items, { prompt = M.config.picker_prompt }, function(_, choice_idx)
        if choice_idx == nil or choice_idx < 1 or choice_idx > #dirs then
            return
        end
        local dir, err = M.jump(choice_idx)
        if err ~= nil then
            notify_failed('DirList', err)
            return
        end
        vim.notify('nav: ' .. tostring(dir), vim.log.levels.INFO)
    end)
end

---:NavDocs -- concise in-repo help for the ring semantics and commands.
---There is no upstream to link: this is Matt's own module, mirrored from
---~/workspace/repos/dotfiles/.config/bash.d/cycled.bash.
local function cmd_docs()
    open_float({
        'nav ring -- directory ring, mirrored from',
        '~/workspace/repos/dotfiles/.config/bash.d/cycled.bash',
        '',
        'Semantics (bash -> nvim):',
        '  swd (save)  -> :DirPush [dir]   push dir (default: cwd)',
        '  cwd (next)  -> :DirNext          cycle forward, wraps around',
        '  Cwd (prev)  -> :DirPrev          cycle backward, wraps around',
        '  zwd (reset) -> :DirReset         clear the ring',
        '',
        'Commands:',
        '  :DirList            pick a ring entry, jump to it (vim.ui.select)',
        '  :NavDocs            this help',
        '  :NavValidate        per-check report, never errors',
        '  :NavUpdateCheck     ring-format migration check (local only)',
        '',
        'Behavior:',
        '  - push validates the directory exists and dedupes it',
        '  - the ring holds at most ring_size_max entries (oldest dropped)',
        '  - :cd vs :lcd follows cd_scope ("global" | "window");',
        '    other windows/tabs are never touched',
        '  - persistence is opt-in (persist_enabled): ring.json under',
        '    stdpath("data")/nav/, written atomically (tmp + rename)',
        '',
        'Keymaps (when keymaps_enabled):',
        '  <leader>dn  DirNext',
        "  <leader>dP  DirPrev   (dp is DAP's Debug: Pause)",
    }, ' nav ring help ')
end

---:NavValidate -- per-check vim.notify; missing pieces are reported,
---never raised.
local function cmd_validate()
    local function check(name, ok, detail)
        local level = ok and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('nav %-10s %-4s %s'):format(name, ok and 'ok' or 'STALE', detail), level)
    end
    check('module', package.loaded['nav'] ~= nil, 'lua/nav/init.lua loaded')
    local stale = {}
    for _, dir in ipairs(M.entries()) do
        if not is_directory(dir) then
            stale[#stale + 1] = dir
        end
    end
    check(
        'entries',
        #stale == 0,
        #stale == 0 and (M.size() .. ' entries, all existing directories')
            or ('stale entries: ' .. table.concat(stale, ', '))
    )
    if M.config.persist_enabled then
        local path = M.ring_path()
        local readable = vim.fn.filereadable(path) == 1
        local writable = false
        local dir = vim.fs.dirname(path)
        if vim.fn.mkdir(dir, 'p') == 1 or vim.fn.isdirectory(dir) == 1 then
            local probe = io.open(path, 'a')
            if probe ~= nil then
                probe:close()
                writable = true
            end
        end
        check(
            'persist',
            readable and writable,
            'ring file '
                .. (readable and 'readable' or 'unreadable')
                .. '/'
                .. (writable and 'writable' or 'not writable')
                .. ': '
                .. path
        )
    else
        check('persist', true, 'disabled (persist_enabled = false)')
    end
    if M.config.keymaps_enabled then
        local next_mapped = vim.fn.maparg(M.config.leader_next, 'n') ~= ''
        local prev_mapped = vim.fn.maparg(M.config.leader_prev, 'n') ~= ''
        check('keymaps', next_mapped and prev_mapped, M.config.leader_next .. '/' .. M.config.leader_prev)
    else
        check('keymaps', true, 'disabled (keymaps_enabled = false)')
    end
end

---:NavUpdateCheck -- no upstream release feed exists for this module
---(Matt's own), so this compares the persisted ring format version
---against the known format and offers migrate / skip. Never errors.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    local current = toolmgr.normalize_version(M.config.ring_format_version) or M.RING_FORMAT_VERSION
    local from, from_err = M.ring_file_version()
    if from_err ~= nil then
        vim.notify('NavUpdateCheck: ' .. from_err .. ' (no upstream; local format only)', vim.log.levels.INFO)
        return
    end
    assert(from ~= nil, 'ring_file_version returned no error but no version')
    local from_norm = toolmgr.normalize_version(from) or '0.0.0'
    if toolmgr.compare_versions(from_norm, current) >= 0 then
        vim.notify(
            ('NavUpdateCheck: ring format %s is current (no upstream; local module)'):format(from),
            vim.log.levels.INFO
        )
        return
    end
    M.config.select_impl({ 'migrate', 'skip' }, {
        prompt = ('ring format %s -> %s: '):format(from, current),
    }, function(choice)
        if choice == 'migrate' then
            local applied, notes = toolmgr.apply_migrations(MIGRATIONS_NAV, from)
            local ok, save_err = M.save_ring()
            if not ok then
                vim.notify(
                    'NavUpdateCheck: migrated but could not re-save: ' .. tostring(save_err),
                    vim.log.levels.WARN
                )
                return
            end
            vim.notify(
                ('NavUpdateCheck: %d migration(s) applied\n%s'):format(applied, table.concat(notes, '\n')),
                vim.log.levels.INFO
            )
        elseif choice == 'skip' then
            vim.notify('NavUpdateCheck: migration skipped', vim.log.levels.INFO)
        end
    end)
end

---Register the leader keymaps. Idempotent: vim.keymap.set overwrites the
---same lhs in place.
local function register_keymaps()
    if not M.config.keymaps_enabled then
        return
    end
    local base = { silent = true, noremap = true }
    vim.keymap.set(
        'n',
        M.config.leader_next,
        cmd_next,
        vim.tbl_extend('force', base, {
            desc = 'Nav: next directory in ring',
        })
    )
    vim.keymap.set(
        'n',
        M.config.leader_prev,
        cmd_prev,
        vim.tbl_extend('force', base, {
            desc = 'Nav: previous directory in ring',
        })
    )
end

---Register commands and keymaps. Idempotent: commands are created once;
---the config is rebuilt on every call. Performs no subprocess I/O. When
---persist_enabled, restores the ring from disk (best-effort: a failure
---warns and leaves the in-memory ring alone).
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    register_keymaps()
    if M.config.persist_enabled then
        local ok, count_or_err = M.restore_ring()
        if not ok then
            vim.notify('nav: ring restore failed: ' .. tostring(count_or_err), vim.log.levels.WARN)
        end
    end
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('DirPush', cmd_push, {
        nargs = '?',
        complete = 'dir',
        desc = 'Push a directory (default: cwd) onto the ring (mirrors swd)',
    })
    api.nvim_create_user_command('DirNext', cmd_next, { desc = 'Cycle forward in the ring (mirrors cwd)' })
    api.nvim_create_user_command('DirPrev', cmd_prev, { desc = 'Cycle backward in the ring (mirrors Cwd)' })
    api.nvim_create_user_command('DirReset', cmd_reset, { desc = 'Clear the ring (mirrors zwd)' })
    api.nvim_create_user_command('DirList', cmd_list, { desc = 'Pick a ring entry and jump to it' })
    api.nvim_create_user_command('NavDocs', cmd_docs, { desc = 'In-repo help for the nav directory ring' })
    api.nvim_create_user_command('NavValidate', cmd_validate, { desc = 'Per-check nav validation report' })
    api.nvim_create_user_command(
        'NavUpdateCheck',
        cmd_update_check,
        { desc = 'Ring-format migration check (no upstream; local only)' }
    )
end

return M
