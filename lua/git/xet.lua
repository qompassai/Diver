-- /qompassai/Diver/lua/git/xet.lua
-- Qompass AI Diver git-xet Integration (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- git-xet is a Git LFS *custom transfer agent*, NOT a filter driver: it
-- REQUIRES git-lfs (lfs owns clean/smudge + the batch API) and only takes
-- over the data transfer when the server picks the "xet" agent during
-- batch negotiation. Verified against huggingface/xet-core
-- (git_xet/README.md, git-xet-v0.2.0 release notes):
--   install: brew install git-xet | the official install.sh | winget
--   `git xet install [--system|--global|--local] [--concurrency N]`
--     registers [lfs "customtransfer.xet"] and bootstraps git lfs install.
--   `git xet track <patterns>` wraps `git lfs track`.
--   verify with `git xet --version`.
--
-- HONESTY RULE (module-wide): Xet acceleration needs an Xet-enabled
-- remote (HF Hub). Plain remotes fall back to the 'basic' transfer, so
-- this module reports the negotiated transfer per remote and never
-- claims speedups that do not apply. Compression is content-defined
-- chunking + CAS dedup; it is configuration-level, and wherever `git xet`
-- reports no chunk stats, this module says so instead of inventing them.
---@module 'git.xet'

local M = {}

local rce = require('security.rce')

---Official install script, verified against huggingface/xet-core main.
local XET_INSTALL_SCRIPT_URL =
    'https://raw.githubusercontent.com/huggingface/xet-core/refs/heads/main/git_xet/install.sh'

local HF_HUB_HOST = 'huggingface.co'
local TRACKED_LINES_MAX = 20 -- `git lfs track` lines shown in status.

---@class git.xet.Detection
---@field lfs utils.toolmgr.BinaryReport git-lfs presence/version report.
---@field xet utils.toolmgr.BinaryReport git-xet presence/version report.

---Detect git-lfs + git-xet presence and versions. Never throws.
---@return git.xet.Detection
function M.detect()
    local toolmgr = require('utils.toolmgr')
    local git = require('git')
    local cfg = git.config
    local lfs = toolmgr.check_binary({ name = 'git-lfs', min_version = cfg.lfs_version_min })
    local xet = toolmgr.check_binary({
        name = 'git-xet',
        version_argv = { 'git', 'xet', '--version' },
        min_version = cfg.xet_version_min,
    })
    return { lfs = lfs, xet = xet }
end

---Which transfer the server will actually negotiate for a remote URL.
---'xet' only for Xet-enabled remotes (HF Hub); everything else -- plain
---GitHub LFS included -- falls back to 'basic'. Pure: garbage in yields
---the safe 'basic' fallback, never an error.
---@param remote_url string|nil Remote URL, e.g. from remote.origin.url.
---@return 'xet'|'basic'
function M.transfer_for_remote(remote_url)
    if type(remote_url) ~= 'string' or remote_url == '' then
        return 'basic'
    end
    local host = remote_url:match('^[^@]+@([^:]+):') or remote_url:match('^%w+://([^/]+)')
    if host ~= nil and host:lower():find(HF_HUB_HOST, 1, true) ~= nil then
        return 'xet'
    end
    return 'basic'
end

---origin remote URL for a repo root, or nil when unset/unreadable.
---@param root string Repo root.
---@return string|nil url
function M.remote_url(root)
    local result, exec_err = rce.safe_exec({ 'git', 'config', '--get', 'remote.origin.url' }, { cwd = root })
    if exec_err ~= nil or result == nil or result.code ~= 0 then
        return nil
    end
    local url = vim.trim(result.stdout or '')
    return url ~= '' and url or nil
end

---Whether `git xet install` has registered the custom transfer agent.
---@param root string Repo root.
---@return boolean
function M.registered(root)
    local result, exec_err = rce.safe_exec({ 'git', 'config', '--get', 'lfs.customtransfer.xet.path' }, { cwd = root })
    if exec_err ~= nil or result == nil or result.code ~= 0 then
        return false
    end
    return vim.trim(result.stdout or '') ~= ''
end

---Patterns currently tracked by git-lfs in this repo (first lines only).
---@param root string Repo root.
---@return string[] patterns
function M.tracked_patterns(root)
    local patterns = {}
    local result, exec_err = rce.safe_exec({ 'git', 'lfs', 'track' }, { cwd = root })
    if exec_err ~= nil or result == nil or result.code ~= 0 then
        return patterns
    end
    local count = 0
    for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
        count = count + 1
        if count > TRACKED_LINES_MAX then
            break
        end
        if vim.trim(line) ~= '' then
            patterns[#patterns + 1] = line
        end
    end
    return patterns
end

---Status lines for :GitXetStatus. Says plainly where git-xet reports
---nothing (per-file chunk/dedup counters do not exist in its CLI).
---@param root string Repo root.
---@return string[] lines
function M.status_lines(root)
    local git = require('git')
    local det = M.detect()
    local lines = {}
    local lfs_state = det.lfs.present and (det.lfs.version or 'present') or 'unavailable'
    lines[#lines + 1] = 'git-lfs: ' .. lfs_state .. ' (required: git-xet is a transfer agent, not a filter)'
    local xet_state = det.xet.present and (det.xet.version or 'present') or 'unavailable'
    lines[#lines + 1] = 'git-xet: ' .. xet_state
    if not git.in_repo(root) then
        lines[#lines + 1] = 'repo: not inside a git work tree'
        return lines
    end
    if M.registered(root) then
        lines[#lines + 1] = 'transfer agent: registered ([lfs "customtransfer.xet"] path=git-xet args=transfer)'
    else
        lines[#lines + 1] = 'transfer agent: NOT registered (run :GitXetInstall, then `git xet install`)'
    end
    local remote = M.remote_url(root)
    lines[#lines + 1] = 'origin: ' .. (remote or '(no origin remote configured)')
    if M.transfer_for_remote(remote) == 'xet' then
        lines[#lines + 1] = "transfer: the server will negotiate 'xet' for this Xet-enabled remote"
    else
        lines[#lines + 1] =
            "transfer: the server negotiates; plain remotes fall back to 'basic' -- no Xet acceleration applies"
    end
    lines[#lines + 1] = 'tracked patterns (git lfs track):'
    local tracked = M.tracked_patterns(root)
    if #tracked == 0 then
        lines[#lines + 1] = '  (none)'
    else
        for _, pattern in ipairs(tracked) do
            lines[#lines + 1] = '  ' .. pattern
        end
    end
    lines[#lines + 1] = 'chunking: content-defined chunking + CAS dedup is configuration-level;'
    lines[#lines + 1] = '  git-xet exposes no per-file chunk/dedup counters, so none are reported.'
    return lines
end

---Register the transfer agent at an explicit scope. Never auto-runs:
---called only from the explicit choice in M.install.
---@param scope '--global'|'--local'
---@return boolean ok
---@return string|nil err
function M.register_scope(scope)
    local result, exec_err = rce.safe_exec({ 'git', 'xet', 'install', scope })
    if exec_err ~= nil then
        return false, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, 'git xet install failed: ' .. vim.trim(result.stderr or '')
    end
    return true, nil
end

---Guided install + registration. Explicit vim.ui.select choices only;
---nothing installs without the user picking it.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function M.install(select_impl)
    local toolmgr = require('utils.toolmgr')
    local pick = select_impl or vim.ui.select
    local items = {
        'Install the git-xet binary via system package manager',
        'Show the official install script command (you run it yourself)',
        'Binary already present: register the transfer agent now',
        'Cancel',
    }
    pick(items, { prompt = 'git-xet install:' }, function(choice)
        if choice == 1 then
            toolmgr.install_package('git-xet', 'git-xet')
        elseif choice == 2 then
            vim.notify(
                "run in a terminal:\n  curl --proto '=https' --tlsv1.2 -sSf " .. XET_INSTALL_SCRIPT_URL .. ' | sh',
                vim.log.levels.INFO
            )
        elseif choice == 3 then
            M.register(select_impl)
        end
    end)
end

---Registration scope picker, shared by M.install and direct use.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function M.register(select_impl)
    local pick = select_impl or vim.ui.select
    local scopes = { '--global', '--local', 'Cancel' }
    pick(scopes, { prompt = 'git xet install scope:' }, function(choice)
        if choice == 1 or choice == 2 then
            local scope = scopes[choice]
            assert(scope == '--global' or scope == '--local', 'scope must be --global or --local')
            local ok, err = M.register_scope(scope)
            if ok then
                vim.notify('git-xet: transfer agent registered (' .. scope .. ')', vim.log.levels.INFO)
            else
                vim.notify('git-xet registration failed: ' .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end)
end

---Track one pattern via `git xet track` (thin wrapper over git lfs track).
---@param pattern string Non-empty track pattern, e.g. '*.safetensors'.
---@param opts? { cwd?: string }
---@return boolean ok
---@return string|nil err
function M.track_pattern(pattern, opts)
    if type(pattern) ~= 'string' or vim.trim(pattern) == '' then
        return false, 'track pattern must be a non-empty string'
    end
    local git = require('git')
    local root, root_err = git.repo_root(opts and opts.cwd)
    if root_err ~= nil then
        return false, root_err
    end
    local det = M.detect()
    if not det.lfs.present then
        return false, 'git-lfs is unavailable (git-xet requires it)'
    end
    if not det.xet.present then
        return false, 'git-xet is unavailable (run :GitXetInstall)'
    end
    local result, exec_err = rce.safe_exec({ 'git', 'xet', 'track', vim.trim(pattern) }, { cwd = root })
    if exec_err ~= nil then
        return false, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, 'git xet track failed: ' .. vim.trim(result.stderr or '')
    end
    return true, nil
end

---Track patterns picker: all configured patterns at once, or one.
---@param select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.
function M.track(select_impl)
    local git = require('git')
    local pick = select_impl or vim.ui.select
    local patterns = git.config.xet_track_patterns
    local items = { 'All configured patterns' }
    for _, pattern in ipairs(patterns) do
        items[#items + 1] = pattern
    end
    items[#items + 1] = 'Cancel'
    pick(items, { prompt = 'git-xet track:' }, function(choice)
        if choice == nil or choice == #items then
            return
        end
        local targets
        if choice == 1 then
            targets = patterns
        else
            targets = { items[choice] }
        end
        local tracked_count, failed = 0, 0
        for _, pattern in ipairs(targets) do
            local ok, err = M.track_pattern(pattern, {})
            if ok then
                tracked_count = tracked_count + 1
            else
                failed = failed + 1
                vim.notify('track ' .. pattern .. ': ' .. tostring(err), vim.log.levels.WARN)
            end
        end
        vim.notify(
            ('git-xet track: %d pattern(s) tracked, %d failed'):format(tracked_count, failed),
            vim.log.levels.INFO
        )
    end)
end

return M
