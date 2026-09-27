-- /qompassai/Diver/lua/ai/herd/personas.lua
-- Qompass AI Herd Personas (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Loader + picker for agent-ctrl specialist personas (Matt's own
-- ~/.config/agent-ctrl/agents/*.md files). The frontmatter schema is
-- `name`, `description`, `category`, optional `mcp-servers`, then the
-- persona body after the closing delimiter. Requiring this module
-- registers nothing and performs no I/O; M.setup() creates the
-- :Personas* commands and the agents dir is scanned lazily on first
-- use. The :HerdSpawn hook (lua/ai/herd/commands.lua) prepends a
-- chosen persona's full text to the spawn task through herd's existing
-- temp-file path, so the text never touches a shell.
---@module 'ai.herd.personas'

local M = {}

local api = vim.api

local setup_done = false

local FRONTMATTER_LINES_MAX = 64 -- frontmatter block length bound.
local OUTPUT_LINES_MAX = 1024 -- rows kept in the :PersonasList float.

---Frontmatter keys the loader recognises. Unknown keys still parse but
---:PersonasValidate reports them as schema warnings.
local KNOWN_FRONTMATTER_KEYS = {
    ['category'] = true,
    ['description'] = true,
    ['mcp-servers'] = true,
    ['name'] = true,
}

---@class PersonasEntry
---@field name string Persona trigger name (frontmatter `name`).
---@field path string Absolute path of the source markdown file.
---@field frontmatter table<string,string> Parsed frontmatter fields.
---@field body string Persona body text after the frontmatter block.
---@field mtime integer File mtime (seconds) at scan time.
---@field size integer File size in bytes at scan time.

---@class PersonasIndex
---@field dir string Agents dir the index was scanned from.
---@field entries PersonasEntry[] Parsed personas, sorted by name.
---@field errors string[] Per-file parse failures, never thrown.
---@field scanned_at integer os.time() of the scan.

---@class PersonasDiff
---@field added string[] Names present in fresh but not in cached.
---@field removed string[] Names present in cached but not in fresh.
---@field changed string[] Names in both with different size or mtime.

M.default_config = {
    -- Agents directory; `~` is expanded at use time, not at require time.
    agents_dir = '~/.config/agent-ctrl/agents',
    -- Max bytes read per persona file; larger files are a parse error.
    body_bytes_max = 65536,
    -- Max description chars shown per row in the picker and list float.
    description_line_max = 120,
    -- Max *.md files scanned per refresh; extras are reported and skipped.
    file_count_max = 256,
    -- Frontmatter block delimiter line.
    frontmatter_delimiter = '---',
    -- Prompt text for the persona picker.
    picker_prompt = 'Persona (optional):',
    -- Current frontmatter schema version; migrations run from this.
    schema_version = '1',
    -- Whether :HerdSpawn offers the persona picker before the task prompt.
    spawn_hook_enabled = true,
    -- The "no persona" choice shown first in the picker.
    spawn_none_label = '<none>',
    -- Rows of the :PersonasList float.
    ui_height = 24,
    -- Cols of the :PersonasList float.
    ui_width = 100,
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Placeholder migration: no frontmatter schema change is known, so
---this documents the migration shape as a clearly-marked template
---(no-op apply). Replace with a real migration when the schema
---version moves; do not invent upstream renames.
---@type utils.toolmgr.Migration[]
local MIGRATIONS_PERSONAS = {
    {
        version = '1',
        description = '[template] no frontmatter schema change known; shape only, no-op',
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---Live index; nil until the first scan.
---@type PersonasIndex?
M.index = nil

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
        error(('personas: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides
---merged, every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('agents_dir', merged.agents_dir, 'string')
    check_type('body_bytes_max', merged.body_bytes_max, 'number')
    check_type('description_line_max', merged.description_line_max, 'number')
    check_type('file_count_max', merged.file_count_max, 'number')
    check_type('frontmatter_delimiter', merged.frontmatter_delimiter, 'string')
    check_type('picker_prompt', merged.picker_prompt, 'string')
    check_type('schema_version', merged.schema_version, 'string')
    check_type('spawn_hook_enabled', merged.spawn_hook_enabled, 'boolean')
    check_type('spawn_none_label', merged.spawn_none_label, 'string')
    check_type('ui_height', merged.ui_height, 'number')
    check_type('ui_width', merged.ui_width, 'number')
    return merged
end

---Expand `~` in the configured agents dir. Runs at use time, never at
---require time.
---@return string dir
local function resolve_agents_dir()
    return vim.fn.expand(M.config.agents_dir)
end

---@param dir string
---@param entries PersonasEntry[]
---@param errors string[]
---@return PersonasIndex index
local function set_index(dir, entries, errors)
    M.index = { dir = dir, entries = entries, errors = errors, scanned_at = os.time() }
    return M.index
end

---Parse one frontmatter line of the form `key: value`.
---@param line string
---@param lnum integer 1-based line number, for error messages.
---@return string? key
---@return string? value
---@return string? err
local function parse_frontmatter_line(line, lnum)
    local key, value = line:match('^%s*([%w%-%_]+)%s*:%s*(.-)%s*$')
    if key == nil then
        return nil, nil, ('line %d: malformed frontmatter (expected "key: value")'):format(lnum)
    end
    return key, value, nil
end

---Parse one persona file's text into its parts. Parse failures are
---returned, never thrown.
---@param text string Bounded file text.
---@param path string Source path, for error messages.
---@param delimiter string Frontmatter delimiter line.
---@return string? name
---@return table<string,string>? frontmatter
---@return string? body
---@return string? err
local function parse_text(text, path, delimiter)
    local lines = vim.split(text, '\n', { plain = true })
    local start_lnum = nil
    for index, line in ipairs(lines) do
        -- The repo's license-header convention (HTML comment lines, as in
        -- the agent-ctrl README) may precede the frontmatter; skip those
        -- and blank lines when locating the opening delimiter.
        if line:match('^%s*$') == nil and line:match('^%s*<!%-%-') == nil then
            if line ~= delimiter then
                return nil, nil, nil, ('%s: missing frontmatter delimiter (first line %d)'):format(path, index)
            end
            start_lnum = index
            break
        end
    end
    if start_lnum == nil then
        return nil, nil, nil, path .. ': missing frontmatter delimiters'
    end
    local frontmatter = {}
    local end_lnum = nil
    local scan_last = math.min(#lines, start_lnum + FRONTMATTER_LINES_MAX)
    for index = start_lnum + 1, scan_last do
        local line = lines[index]
        if line == delimiter then
            end_lnum = index
            break
        end
        if line:match('^%s*$') == nil then
            local key, value, line_err = parse_frontmatter_line(line, index)
            if line_err ~= nil then
                return nil, nil, nil, path .. ': ' .. line_err
            end
            frontmatter[key] = value
        end
    end
    if end_lnum == nil then
        return nil, nil, nil, path .. ': frontmatter block not closed'
    end
    local name = frontmatter['name']
    if type(name) ~= 'string' or vim.trim(name) == '' then
        return nil, nil, nil, path .. ": missing required frontmatter 'name'"
    end
    local body_lines = {}
    for index = end_lnum + 1, #lines do
        body_lines[#body_lines + 1] = lines[index]
    end
    local body = vim.trim(table.concat(body_lines, '\n'))
    if body == '' then
        return nil, nil, nil, path .. ': empty body'
    end
    return vim.trim(name), frontmatter, body, nil
end

---Read-only loader: parse every `*.md` in dir into persona entries.
---Failures land in `errors`, never thrown. Bounded by
---config.file_count_max files and config.body_bytes_max bytes per file.
---@param dir string Agents directory (already expanded).
---@return PersonasEntry[] entries Sorted by name.
---@return string[] errors One line per failure.
function M.load_personas(dir)
    local entries = {}
    local errors = {}
    if type(dir) ~= 'string' or dir == '' then
        errors[#errors + 1] = 'agents dir is not a usable path'
        return entries, errors
    end
    if vim.fn.isdirectory(dir) ~= 1 then
        errors[#errors + 1] = 'agents dir not found or not a directory: ' .. dir
        return entries, errors
    end
    local paths = vim.fn.globpath(dir, '*.md', false, true)
    table.sort(paths)
    local cap = math.max(math.floor(M.config.file_count_max), 1)
    if #paths > cap then
        errors[#errors + 1] = ('%d files exceed file_count_max %d; first %d scanned'):format(#paths, cap, cap)
    end
    local seen = {}
    for index = 1, math.min(#paths, cap) do
        local path = paths[index]
        local stat = vim.uv.fs_stat(path)
        local size = 0
        local mtime = 0
        if stat ~= nil then
            if type(stat.size) == 'number' then
                size = stat.size
            end
            if type(stat.mtime) == 'table' and type(stat.mtime.sec) == 'number' then
                mtime = stat.mtime.sec
            end
        end
        local file, open_err = io.open(path, 'r')
        if file == nil then
            errors[#errors + 1] = path .. ': cannot read: ' .. tostring(open_err)
        else
            local max_bytes = math.max(math.floor(M.config.body_bytes_max), 1)
            local text = file:read(max_bytes + 1)
            file:close()
            if type(text) ~= 'string' or text == '' then
                errors[#errors + 1] = path .. ': empty file'
            elseif #text > max_bytes then
                errors[#errors + 1] = ('%s: exceeds body_bytes_max %d'):format(path, max_bytes)
            else
                local name, frontmatter, body, parse_err = parse_text(text, path, M.config.frontmatter_delimiter)
                if parse_err ~= nil then
                    errors[#errors + 1] = parse_err
                elseif seen[name] ~= nil then
                    local msg = '%s: duplicate persona name %q (kept %s)'
                    errors[#errors + 1] = msg:format(path, name, seen[name])
                else
                    seen[name] = path
                    entries[#entries + 1] = {
                        name = name,
                        path = path,
                        frontmatter = frontmatter,
                        body = body,
                        mtime = mtime,
                        size = size,
                    }
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.name < b.name
    end)
    return entries, errors
end

---Rescan the agents dir and rebuild M.index. Never writes to disk.
---@return PersonasIndex index
function M.refresh()
    local dir = resolve_agents_dir()
    local entries, errors = M.load_personas(dir)
    return set_index(dir, entries, errors)
end

---@return PersonasIndex index
local function ensure_loaded()
    if M.index == nil then
        return M.refresh()
    end
    return M.index
end

---Sorted persona summaries for pickers and floats. Pure data, no UI.
---@return { name: string, description: string }[] list
function M.list_personas()
    local list = {}
    for _, entry in ipairs(ensure_loaded().entries) do
        local description = entry.frontmatter['description'] or ''
        if #description > M.config.description_line_max then
            description = description:sub(1, M.config.description_line_max) .. '…'
        end
        list[#list + 1] = { name = entry.name, description = description }
    end
    return list
end

---One parsed persona by name, or nil.
---@param name string
---@return PersonasEntry?
function M.get(name)
    if type(name) ~= 'string' then
        return nil
    end
    for _, entry in ipairs(ensure_loaded().entries) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

---Offer the personas in vim.ui.select: the none label first, then each
---persona with its one-line description. Cancel or none calls back nil.
---No picker when the index is empty: straight to nil.
---@param on_pick fun(name: string?)
function M.pick_persona(on_pick)
    assert(type(on_pick) == 'function', 'on_pick must be a function')
    local descriptions = {}
    local names = {}
    for _, item in ipairs(M.list_personas()) do
        names[#names + 1] = item.name
        descriptions[item.name] = item.description
    end
    if #names == 0 then
        on_pick(nil)
        return
    end
    local none_label = M.config.spawn_none_label
    local choices = { none_label }
    for _, name in ipairs(names) do
        choices[#choices + 1] = name
    end
    vim.ui.select(choices, {
        prompt = M.config.picker_prompt,
        format_item = function(choice)
            if choice == none_label then
                return choice
            end
            local description = descriptions[choice] or ''
            if description ~= '' then
                return choice .. ' — ' .. description
            end
            return choice
        end,
    }, function(choice)
        if choice == nil or choice == none_label then
            on_pick(nil)
            return
        end
        on_pick(choice)
    end)
end

---Full persona text for a spawn prompt: frontmatter re-rendered as a
---`---` header (keys sorted for deterministic output), then the body.
---@param name string
---@return string? text nil for an unknown name.
function M.render_prompt(name)
    local entry = M.get(name)
    if entry == nil then
        return nil
    end
    local keys = {}
    for key in pairs(entry.frontmatter) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local delimiter = M.config.frontmatter_delimiter
    local lines = { delimiter }
    for _, key in ipairs(keys) do
        lines[#lines + 1] = key .. ': ' .. entry.frontmatter[key]
    end
    lines[#lines + 1] = delimiter
    lines[#lines + 1] = ''
    lines[#lines + 1] = entry.body
    return table.concat(lines, '\n')
end

---Prepend persona text to an optional task, for :HerdSpawn. The combined
---text travels through herd's existing temp-file path; nothing is
---interpolated into a shell. Returns nil when both are blank.
---@param persona_text string? Rendered persona, from render_prompt.
---@param task string? The user's optional task text.
---@return string? combined
function M.with_persona(persona_text, task)
    local persona = (type(persona_text) == 'string' and persona_text:match('%S') ~= nil) and persona_text or nil
    local text = (type(task) == 'string' and task:match('%S') ~= nil) and task or nil
    if persona == nil then
        return text
    end
    if text == nil then
        return persona
    end
    return persona .. '\n\n' .. text
end

---Whether :HerdSpawn offers the persona picker. Checked by
---lua/ai/herd/commands.lua at spawn time.
---@return boolean
function M.spawn_hook_enabled()
    return M.config.spawn_hook_enabled
end

---Diff a fresh scan against the cached index: new, removed, and changed
---(size or mtime) personas. Pure: scans nothing itself.
---@param fresh PersonasEntry[] Fresh scan, e.g. from M.load_personas.
---@return PersonasDiff diff
function M.diff_index(fresh)
    local cached = {}
    if M.index ~= nil then
        for _, entry in ipairs(M.index.entries) do
            cached[entry.name] = { mtime = entry.mtime, size = entry.size }
        end
    end
    local seen_fresh = {}
    local added = {}
    local changed = {}
    for _, entry in ipairs(fresh) do
        seen_fresh[entry.name] = true
        local old = cached[entry.name]
        if old == nil then
            added[#added + 1] = entry.name
        elseif old.mtime ~= entry.mtime or old.size ~= entry.size then
            changed[#changed + 1] = entry.name
        end
    end
    local removed = {}
    for name in pairs(cached) do
        if not seen_fresh[name] then
            removed[#removed + 1] = name
        end
    end
    table.sort(added)
    table.sort(removed)
    table.sort(changed)
    return { added = added, removed = removed, changed = changed }
end

---Open a centered, minimal float. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
local function open_float(lines, title)
    local shown = {}
    for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
        shown[#shown + 1] = lines[index]
    end
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, shown)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'diver-personas'
    local width = math.min(M.config.ui_width, vim.o.columns - 4)
    local height = math.min(M.config.ui_height, vim.o.lines - 4)
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close personas float' })
end

---:PersonasList -- every persona with its trigger name and description.
local function cmd_list()
    local index = ensure_loaded()
    local lines = {}
    if #index.entries == 0 then
        lines = { 'no personas found in ' .. index.dir }
    else
        for _, entry in ipairs(index.entries) do
            local description = entry.frontmatter['description'] or ''
            local category = entry.frontmatter['category'] or ''
            local line = entry.name .. ' — ' .. description
            if category ~= '' then
                line = line .. ' [' .. category .. ']'
            end
            lines[#lines + 1] = line
        end
    end
    for _, err in ipairs(index.errors) do
        lines[#lines + 1] = 'parse error: ' .. err
    end
    open_float(lines, ' personas (' .. #index.entries .. ') ')
end

---:PersonasDocs -- open the local agent-ctrl schema doc. There is no
---upstream reference for these personas (they are Matt's own dotfiles),
---so the local README next to the agents dir is the canonical source.
local function cmd_docs()
    local doc = vim.fs.dirname(resolve_agents_dir()) .. '/README.md'
    if vim.fn.filereadable(doc) ~= 1 then
        local msg = 'PersonasDocs: no local schema doc at ' .. doc .. ' (there is no upstream reference)'
        vim.notify(msg, vim.log.levels.WARN)
        return
    end
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, doc)
    if not opened then
        vim.notify('personas schema doc: ' .. doc, vim.log.levels.INFO)
    end
end

---:PersonasValidate -- one vim.notify per check. A missing agents dir
---reports "unavailable", never an error.
local function cmd_validate()
    local dir = resolve_agents_dir()
    if vim.fn.isdirectory(dir) ~= 1 then
        vim.notify('personas agents-dir unavailable: ' .. dir, vim.log.levels.WARN)
        return
    end
    vim.notify('personas agents-dir ok: ' .. dir, vim.log.levels.INFO)
    -- The loader already rejects empty names and bodies as parse
    -- errors, so the counts below cover the non-empty name/body check.
    local index = M.refresh()
    local parse_level = #index.errors == 0 and vim.log.levels.INFO or vim.log.levels.WARN
    local msg = ('personas parsed: %d ok, %d failed'):format(#index.entries, #index.errors)
    vim.notify(msg, parse_level)
    for _, err in ipairs(index.errors) do
        vim.notify('personas parse failed: ' .. err, vim.log.levels.WARN)
    end
    local unknown = {}
    for _, entry in ipairs(index.entries) do
        for key in pairs(entry.frontmatter) do
            if KNOWN_FRONTMATTER_KEYS[key] == nil then
                unknown[#unknown + 1] = entry.name .. ': unknown frontmatter key ' .. key
            end
        end
    end
    local schema_level = #unknown == 0 and vim.log.levels.INFO or vim.log.levels.WARN
    local schema_msg = ('personas schema: %d entries, %d unknown keys'):format(#index.entries, #unknown)
    vim.notify(schema_msg, schema_level)
    for _, line in ipairs(unknown) do
        vim.notify('personas ' .. line, vim.log.levels.WARN)
    end
end

---:PersonasUpdateCheck -- there is no upstream release feed for these
---personas (they are Matt's own dotfiles), so "update" means rescan the
---agents dir, diff against the cached index, and offer: refresh the
---in-memory index, show the diff, or skip. A template no-op migration
---is kept for a future frontmatter schema version.
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    local _, notes = toolmgr.apply_migrations(MIGRATIONS_PERSONAS, M.config.schema_version)
    local dir = resolve_agents_dir()
    if vim.fn.isdirectory(dir) ~= 1 then
        vim.notify('PersonasUpdateCheck: agents dir unavailable: ' .. dir, vim.log.levels.WARN)
        return
    end
    local fresh, fresh_errors = M.load_personas(dir)
    local diff = M.diff_index(fresh)
    local summary = ('personas changes: %d added, %d removed, %d changed; %d parse errors'):format(
        #diff.added,
        #diff.removed,
        #diff.changed,
        #fresh_errors
    )
    if #notes > 0 then
        summary = summary .. ' | migrations: ' .. table.concat(notes, '; ')
    end
    vim.ui.select({ 'Refresh in-memory index', 'Show diff', 'Skip' }, {
        prompt = summary .. ' — action?',
    }, function(choice)
        if choice == 'Refresh in-memory index' then
            set_index(dir, fresh, fresh_errors)
            vim.notify('PersonasUpdateCheck: index refreshed', vim.log.levels.INFO)
        elseif choice == 'Show diff' then
            local lines = { summary }
            local sections = {
                { 'added', diff.added },
                { 'removed', diff.removed },
                { 'changed', diff.changed },
            }
            for _, section in ipairs(sections) do
                if #section[2] > 0 then
                    lines[#lines + 1] = section[1] .. ':'
                    for _, name in ipairs(section[2]) do
                        lines[#lines + 1] = '  ' .. name
                    end
                end
            end
            for _, err in ipairs(fresh_errors) do
                lines[#lines + 1] = 'parse error: ' .. err
            end
            open_float(lines, ' personas changes ')
        end
    end)
end

---Register the :Personas* commands. Idempotent: commands are created
---once; the config is rebuilt on every call. Performs no I/O itself:
---the agents dir is scanned lazily on first use.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('PersonasList', cmd_list, { desc = 'List agent-ctrl personas in a float' })
    api.nvim_create_user_command('PersonasDocs', cmd_docs, {
        desc = 'Open the local agent-ctrl schema doc (no upstream exists)',
    })
    api.nvim_create_user_command('PersonasValidate', cmd_validate, {
        desc = 'Validate the agents dir and every persona',
    })
    api.nvim_create_user_command('PersonasUpdateCheck', cmd_update_check, {
        desc = 'Rescan the agents dir and diff against the cached index',
    })
end

return M
