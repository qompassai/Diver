-- /qompassai/Diver/lua/email/clients/init.lua
-- Qompass AI Diver Email Client Chooser (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- :EmailClient -- a two-step chooser between the neomutt and aerc
-- backends. The client choice can be remembered in
-- stdpath('data') .. '/email/client_choice' (atomic tmp+rename write);
-- nothing is persisted unless the user explicitly picks "remember".
-- Backends are required lazily, only when opened.
---@module 'comms.clients'

local M = {}

local api = vim.api

local setup_done = false

local CLIENTS = { 'neomutt', 'aerc' }

M.default_config = {
    -- File name under stdpath('data') .. '/email/' holding the choice.
    choice_file_name = 'client_choice',
    -- Written into the persisted file; readers reject other versions.
    choice_format_version = 1,
    -- When false, save_choice refuses (the choice stays in-memory).
    persist_enabled = true,
    -- vim.ui.select replacement; nil uses the real one (test seam).
    select_impl = nil,
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Type-check one config option. Programmer errors raise; expected
---absences (nil optionals) stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= expected then
        error(('clients: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('choice_file_name', merged.choice_file_name, 'string')
    check_type('choice_format_version', merged.choice_format_version, 'number')
    check_type('persist_enabled', merged.persist_enabled, 'boolean')
    check_type('select_impl', merged.select_impl, 'function', true)
    if vim.trim(merged.choice_file_name) == '' then
        error('clients: option choice_file_name must not be blank', 2)
    end
    return merged
end

---Whether name is one of the known backends.
---@param name any Candidate.
---@return boolean known
function M.is_client(name)
    for _, client in ipairs(CLIENTS) do
        if name == client then
            return true
        end
    end
    return false
end

---Absolute path of the persisted choice file.
---@return string path
function M.choice_path()
    return vim.fs.joinpath(vim.fn.stdpath('data'), 'email', M.config.choice_file_name)
end

---Read the persisted choice. Returns nil when nothing was saved, the
---file is corrupt, or the format version mismatches: a corrupt file is
---reported and ignored, never raised.
---@return string|nil client 'neomutt' or 'aerc'.
function M.read_choice()
    local file = io.open(M.choice_path(), 'r')
    if file == nil then
        return nil
    end
    local text = file:read('*l') or ''
    file:close()
    local version, client = text:match('^(%d+):(%w+)$')
    if tonumber(version) ~= M.config.choice_format_version or not M.is_client(client) then
        return nil
    end
    return client
end

---Persist the client choice atomically (tmp + os.rename). Refuses
---unknown clients and, when persist_enabled is false, any write.
---@param client string 'neomutt' or 'aerc'.
---@return boolean ok
---@return string|nil err
function M.save_choice(client)
    if not M.is_client(client) then
        return false, 'unknown client: ' .. tostring(client)
    end
    if not M.config.persist_enabled then
        return false, 'persistence disabled (persist_enabled=false)'
    end
    local path = M.choice_path()
    -- vim.fn.mkdir throws E739 when a path component exists as a file,
    -- so the pcall is load-bearing.
    local mkdir_ok = pcall(vim.fn.mkdir, vim.fs.dirname(path), 'p')
    if not mkdir_ok and vim.fn.isdirectory(vim.fs.dirname(path)) ~= 1 then
        return false, 'cannot create directory ' .. vim.fs.dirname(path)
    end
    local tmp = path .. '.tmp'
    local file, file_err = io.open(tmp, 'w')
    if file == nil then
        return false, ('cannot write %s: %s'):format(tmp, tostring(file_err))
    end
    file:write(('%d:%s\n'):format(M.config.choice_format_version, client))
    file:close()
    local ok, rename_err = os.rename(tmp, path)
    if not ok then
        os.remove(tmp)
        return false, ('cannot rename %s to %s: %s'):format(tmp, path, tostring(rename_err))
    end
    return true, nil
end

---Delete the persisted choice. Missing file is fine (idempotent).
---@return boolean ok
---@return string|nil err
function M.forget_choice()
    local ok, err = os.remove(M.choice_path())
    if ok then
        return true, nil
    end
    if err ~= nil and err:find('No such file', 1, true) ~= nil then
        return true, nil
    end
    return false, tostring(err)
end

---Require a backend lazily. Returns nil + err for unknown clients.
---@param client string 'neomutt' or 'aerc'.
---@return table|nil backend
---@return string|nil err
function M.backend(client)
    if client == 'neomutt' then
        return require('comms.clients.neomutt'), nil
    end
    if client == 'aerc' then
        return require('comms.clients.aerc'), nil
    end
    return nil, 'unknown client: ' .. tostring(client)
end

---Open a backend's interactive client. Idempotent-safe.
---@param client string 'neomutt' or 'aerc'.
---@return boolean ok
---@return string|nil err
function M.open_client(client)
    local backend, err = M.backend(client)
    if backend == nil then
        return false, err
    end
    return backend.open()
end

---Two-step chooser: pick a client, then pick whether to remember it.
---Nothing is persisted unless the user explicitly picks "remember".
local function choose_client()
    local impl = M.config.select_impl or vim.ui.select
    impl(CLIENTS, { prompt = 'Email client:' }, function(client)
        if client == nil then
            vim.notify('EmailClient: cancelled', vim.log.levels.INFO)
            return
        end
        impl({ 'Just this time', 'Remember this choice' }, { prompt = ('Open %s and:'):format(client) }, function(how)
            if how == nil then
                vim.notify('EmailClient: cancelled', vim.log.levels.INFO)
                return
            end
            if how == 'Remember this choice' then
                local ok, err = M.save_choice(client)
                if not ok then
                    vim.notify('EmailClient: not saved: ' .. tostring(err), vim.log.levels.WARN)
                end
            end
            local ok, err = M.open_client(client)
            if not ok then
                vim.notify('EmailClient: ' .. tostring(err), vim.log.levels.ERROR)
            end
        end)
    end)
end

---:EmailClient [arg] -- arg in {neomutt, aerc, ask, forget}.
---No arg opens the remembered client, or asks when none is saved.
---@param arg string|nil Command argument.
local function cmd_email_client(arg)
    if arg == 'forget' then
        local ok, err = M.forget_choice()
        if ok then
            vim.notify('EmailClient: remembered choice forgotten', vim.log.levels.INFO)
        else
            vim.notify('EmailClient: ' .. tostring(err), vim.log.levels.ERROR)
        end
        return
    end
    if arg == 'ask' or arg == '' or arg == nil then
        if arg == '' or arg == nil then
            local saved = M.read_choice()
            if saved ~= nil then
                local ok, err = M.open_client(saved)
                if not ok then
                    vim.notify('EmailClient: ' .. tostring(err), vim.log.levels.ERROR)
                end
                return
            end
        end
        choose_client()
        return
    end
    if M.is_client(arg) then
        local ok, err = M.open_client(arg)
        if not ok then
            vim.notify('EmailClient: ' .. tostring(err), vim.log.levels.ERROR)
        end
        return
    end
    vim.notify('EmailClient: unknown client "' .. arg .. '" (neomutt, aerc, ask, forget)', vim.log.levels.ERROR)
end

---Register :EmailClient. Idempotent: the command is created once; the
---config is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('EmailClient', function(cmd_opts)
        cmd_email_client(cmd_opts.args ~= '' and cmd_opts.args or nil)
    end, {
        nargs = '?',
        complete = function()
            return { 'neomutt', 'aerc', 'ask', 'forget' }
        end,
        desc = 'Choose and open the email client (neomutt | aerc); optionally remember it',
    })
end

return M
