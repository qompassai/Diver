-- /qompassai/Diver/lua/ai/huggingface/init.lua
-- Qompass AI Diver Hugging Face Hub Integration (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Search / download / upload against the Hugging Face Hub, plus xet
-- transfer status and tooling update checks. Requiring this module
-- registers nothing and performs no I/O; M.setup() creates the user
-- commands. Every subprocess goes through security.rce.safe_exec in
-- argv form; Hub REST calls are bounded curl. A missing tool reports
-- "unavailable", never an error.
--
-- Verified facts (checked 2026-09-27, do not "update" from memory):
--   * `hf` is the current CLI (replaces deprecated `huggingface-cli`);
--     it ships with the huggingface_hub Python package and via the
--     standalone installer at https://hf.co/cli/install.sh. There is NO
--     github.com/huggingface/hf repo (404); release tracking uses
--     github.com/huggingface/huggingface_hub.
--   * `hf download <repo> [--revision <rev>]`, `hf upload <repo> <path>`
--     (verified against huggingface_hub 2.0.0).
--   * Python fallback entry point: `python -m huggingface_hub.cli.hf`
--     (verified: __main__ guard present in 2.0.0). The old
--     `huggingface_hub.commands.huggingface_cli` module is GONE in 2.0.0.
--   * hf-xet is the pip package `hf-xet` (import `hf_xet`), installable
--     as the `huggingface_hub[hf-xet]` extra; huggingface_hub 2.0.0
--     depends on it unconditionally on x86_64/aarch64.
--   * The public Hub API exposes NO per-repo `xetEnabled` flag, but
--     GET /api/models/{ns}/{repo}/xet-read-token/{rev} is public for
--     public repos: HTTP 200 with a casUrl field means Xet-enabled
--     (see ai.huggingface.api.repo_xet_probe).
-- HF_TOKEN is read from vim.env at use time only, never stored in
-- config/files/logs, and never passed on any argv (the `hf` CLI reads
-- it from its own environment).
---@module 'ai.huggingface'

local M = {}

local api = vim.api

local rce = require('security.rce')
local hfapi = require('ai.huggingface.api')

local setup_done = false

---Newest hf/huggingface_hub release known to this module (verified:
---PyPI huggingface_hub 2.0.0 on 2026-09-27; the GitHub releases of
---huggingface/huggingface_hub track the same version line).
local HF_VERSION_KNOWN = '2.0.0'
---Oldest git-xet this module reports on (verified tag: git-xet-v0.2.0).
local XET_VERSION_KNOWN = '0.2.0'
local REPO_PATTERN = '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -- owner/name shape.
local OUTPUT_TAIL_MAX = 40 -- output lines kept for transfer-stat floats.
local WALK_FILES_MAX = 500 -- files listed in an upload dry-run preview.
local PIP_TIMEOUT_MS = 15000 -- wall-clock cap for `pip show` probes.

---@class ai.huggingface.Check
---@field name string Tool or aspect probed, e.g. 'hf'.
---@field status 'ok'|'unavailable'
---@field detail string One-line human summary.

M.default_config = {
    -- Hub REST base (verified: https://huggingface.co/docs/hub/api).
    api_base = 'https://huggingface.co',
    -- Uploads always show a dry-run preview and require explicit confirm.
    confirm_upload = true,
    -- Verified live 2026-09-27.
    docs_url = 'https://huggingface.co/docs/hub/api',
    -- Rows of the detail/preview floating windows.
    float_height = 24,
    -- Cols of the detail/preview floating windows.
    float_width = 100,
    -- The `hf` CLI binary name (standalone install or pipx/uvx shim).
    hf_bin = 'hf',
    -- Pip spec offered by the guided hf-xet install prompt.
    hf_xet_package = 'huggingface_hub[hf-xet]',
    -- Results requested per Hub search call (clamped to 1..100).
    page_size = 20,
    -- Papers search path (verified: hybrid semantic + full-text).
    papers_endpoint = '/api/papers/search',
    -- Python used for the huggingface_hub fallback and pip probes.
    python_bin = 'python3',
    -- Picker entries shown per search (Hub returns at most page_size).
    results_max = 50,
    -- Wall-clock cap per Hub API request, seconds.
    search_timeout_s = 15,
    -- Test seam for vim.ui.select; nil means the real picker.
    select_impl = nil,
    -- Wall-clock cap per hf download/upload spawn, milliseconds.
    timeout_ms = 300000,
}

---Live configuration. Rebuilt from M.default_config on every setup().
---@type table
M.config = vim.deepcopy(M.default_config)

---Placeholder migrations: no upstream config-key rename is known for any
---of these tools, so each entry documents the migration shape as a
---clearly-marked template (no-op apply). Replace with a real migration
---when upstream renames a key we depend on.
local MIGRATIONS_TEMPLATE_NOTE = '[template] no upstream config rename known; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS_HF = {
    {
        version = '2.0.0',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---@type utils.toolmgr.Migration[]
local MIGRATIONS_HUB = {
    {
        version = '2.0.0',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---@type utils.toolmgr.Migration[]
local MIGRATIONS_XET = {
    {
        version = '0.2.0',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

---Type-check one config option. Programmer errors raise; a nil
---select_impl is the documented "use the real picker" default.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
---@param optional? boolean When true, nil is allowed.
local function check_type(name, value, expected, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= expected then
        error(('huggingface: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

---Build the live config: factory defaults deep-copied, overrides merged,
---every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    check_type('config', config, 'table', true)
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('api_base', merged.api_base, 'string')
    check_type('confirm_upload', merged.confirm_upload, 'boolean')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('hf_bin', merged.hf_bin, 'string')
    check_type('hf_xet_package', merged.hf_xet_package, 'string')
    check_type('page_size', merged.page_size, 'number')
    check_type('papers_endpoint', merged.papers_endpoint, 'string')
    check_type('python_bin', merged.python_bin, 'string')
    check_type('results_max', merged.results_max, 'number')
    check_type('search_timeout_s', merged.search_timeout_s, 'number')
    check_type('select_impl', merged.select_impl, 'function', true)
    check_type('timeout_ms', merged.timeout_ms, 'number')
    return merged
end

---Read HF_TOKEN at use time only. Never stored, never logged, never
---placed on any argv (the `hf` CLI inherits it from the environment).
---@return string|nil token
function M.hf_token()
    local token = vim.env.HF_TOKEN
    if type(token) ~= 'string' or vim.trim(token) == '' then
        return nil
    end
    return token
end

---Validate an 'owner/name' repo id before it reaches any argv.
---@param repo string|nil Candidate repo id.
---@return string|nil clean Trimmed id.
---@return string|nil err
local function validate_repo_id(repo)
    local clean = vim.trim(repo or '')
    if clean == '' then
        return nil, 'a repo id like owner/name is required'
    end
    -- '..' anywhere is a path-traversal smell; repo ids never need it.
    if not clean:match(REPO_PATTERN) or clean:find('..', 1, true) then
        return nil, 'repo id must look like owner/name, got ' .. clean
    end
    return clean, nil
end

---Notify a command failure in one canonical shape.
---@param what string Command name for the message.
---@param err any Failure reason.
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
end

---Open a centered, minimal float for command output. `q` closes it.
---@param lines string[] Body lines.
---@param title string Float title.
local function open_float(lines, title)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'diver-huggingface'
    local win_width = math.min(M.config.float_width, vim.o.columns - 4)
    local win_height = math.min(M.config.float_height, vim.o.lines - 4)
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
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close huggingface float' })
end

---@class ai.huggingface.ToolInfo
---@field kind 'hf'|'python'|'unavailable' How downloads/uploads will run.
---@field prefix string[] argv words before the subcommand.
---@field version string|nil Detected version, if parseable.
---@field detail string One-line human summary.

---Detect the download/upload backend: the `hf` CLI first, then the
---verified `python -m huggingface_hub.cli.hf` entry point. Never throws.
---@return ai.huggingface.ToolInfo tool
function M.detect_tool()
    local toolmgr = require('utils.toolmgr')
    local hf_bin = M.config.hf_bin
    local report = toolmgr.check_binary({ name = hf_bin, version_argv = { hf_bin, 'version' } })
    if report.present then
        return {
            kind = 'hf',
            prefix = { hf_bin },
            version = report.version,
            detail = hf_bin .. (report.version ~= nil and (' ' .. report.version) or ''),
        }
    end
    local python_bin = M.config.python_bin
    local probe = rce.safe_exec(
        { python_bin, '-m', 'huggingface_hub.cli.hf', '--help' },
        { timeout_ms = PIP_TIMEOUT_MS }
    )
    if probe ~= nil then
        local version = M.pip_package_version('huggingface_hub')
        return {
            kind = 'python',
            prefix = { python_bin, '-m', 'huggingface_hub.cli.hf' },
            version = version,
            detail = python_bin
                .. ' -m huggingface_hub.cli.hf'
                .. (version ~= nil and (' (huggingface_hub ' .. version .. ')') or ''),
        }
    end
    return {
        kind = 'unavailable',
        prefix = {},
        version = nil,
        detail = 'unavailable: neither '
            .. hf_bin
            .. ' nor python -m huggingface_hub.cli.hf found (install the hf CLI: https://hf.co/cli/install.sh)',
    }
end

---Installed version of a pip package via `pip show`. Nil when absent.
---@param package string Pip package name, e.g. 'huggingface_hub'.
---@return string|nil version
function M.pip_package_version(package)
    local result, exec_err = rce.safe_exec(
        { M.config.python_bin, '-m', 'pip', 'show', package },
        { timeout_ms = PIP_TIMEOUT_MS }
    )
    if exec_err ~= nil or result == nil or result.code ~= 0 then
        return nil
    end
    local version = (result.stdout or ''):match('^Version:%s*(%S+)')
    return version
end

---Whether the hf-xet download path is available (`pip show hf-xet`).
---@return boolean present
function M.hf_xet_present()
    local result, exec_err = rce.safe_exec(
        { M.config.python_bin, '-m', 'pip', 'show', 'hf-xet' },
        { timeout_ms = PIP_TIMEOUT_MS }
    )
    return exec_err == nil and result ~= nil and result.code == 0
end

---Offer the guided hf-xet install when the package is absent. Returns
---'ok' when xet is present, 'no-xet' to continue on the standard
---transfer path, or 'cancelled'. Never installs without the explicit
---vim.ui.select choice.
---@param select_impl fun(items: string[], opts: table, on_choice: fun(choice: integer|nil))
---@return 'ok'|'no-xet'|'cancelled'
local function maybe_ensure_hf_xet(select_impl)
    if M.hf_xet_present() then
        return 'ok'
    end
    local decision = 'cancelled'
    local items = {
        'Install ' .. M.config.hf_xet_package .. ' via pip (opens a terminal)',
        'Continue without xet (standard transfer)',
        'Cancel',
    }
    select_impl(items, { prompt = 'hf-xet is not installed:' }, function(choice)
        if choice == 1 then
            vim.cmd('botright 15split')
            local buf = api.nvim_get_current_buf()
            vim.fn.termopen({ M.config.python_bin, '-m', 'pip', 'install', M.config.hf_xet_package })
            api.nvim_buf_set_name(buf, 'huggingface://install/hf-xet')
            vim.notify(
                'huggingface: installing hf-xet in the terminal below; re-run the command when it finishes',
                vim.log.levels.INFO
            )
            decision = 'cancelled'
        elseif choice == 2 then
            decision = 'no-xet'
        end
    end)
    return decision
end

---@class ai.huggingface.TransferOutcome
---@field stats string|nil Tool-reported transfer stats, if any.
---@field xet 'ok'|'no-xet' Whether the xet path was active.

---Download a repo via the detected backend. Validates the repo id, runs
---the xet offer, then spawns. Returns the tool's own stats when it
---reports any; the caller renders them.
---@param repo string 'owner/name'.
---@param revision string|nil Revision, e.g. 'main'.
---@param opts? { select_impl?: fun(items: string[], opts: table, on_choice: fun(choice: integer|nil)) }
---@return boolean ok
---@return ai.huggingface.TransferOutcome|string result_or_err
function M.download(repo, revision, opts)
    local clean, repo_err = validate_repo_id(repo)
    if repo_err ~= nil then
        return false, repo_err
    end
    local tool = M.detect_tool()
    if tool.kind == 'unavailable' then
        return false, tool.detail
    end
    local pick = (opts and opts.select_impl) or M.config.select_impl or vim.ui.select
    local xet = maybe_ensure_hf_xet(pick)
    if xet == 'cancelled' then
        return false, 'cancelled'
    end
    local argv = {}
    for _, word in ipairs(tool.prefix) do
        argv[#argv + 1] = word
    end
    argv[#argv + 1] = 'download'
    argv[#argv + 1] = clean
    local rev = vim.trim(revision or '')
    if rev ~= '' then
        argv[#argv + 1] = '--revision'
        argv[#argv + 1] = rev
    end
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return false, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, 'download failed: ' .. vim.trim(result.stderr or result.stdout or '')
    end
    local stats = vim.trim((result.stdout or '') .. '\n' .. (result.stderr or ''))
    if stats == '' then
        stats = nil
    end
    return true, { stats = stats, xet = xet }
end

---@class ai.huggingface.UploadFile
---@field path string Absolute path.
---@field size integer Bytes.

---@class ai.huggingface.UploadPlan
---@field argv string[] Exact argv that will run (words, not a shell string).
---@field files ai.huggingface.UploadFile[] Files to upload, bounded.
---@field total_bytes integer
---@field truncated boolean True when the walk hit WALK_FILES_MAX.

---Walk a path into an upload plan: the exact argv plus every file with
---its size. Symlinks and non-files are skipped; the walk is bounded.
---@param local_path string File or directory to upload.
---@param repo string 'owner/name'.
---@return ai.huggingface.UploadPlan|nil plan
---@return string|nil err
function M.upload_plan(local_path, repo)
    local clean, repo_err = validate_repo_id(repo)
    if repo_err ~= nil then
        return nil, repo_err
    end
    local path = vim.trim(local_path or '')
    if path == '' then
        return nil, 'a local path is required'
    end
    local abs = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
    local stat = vim.uv.fs_stat(abs)
    if stat == nil then
        return nil, 'path does not exist: ' .. path
    end
    local tool = M.detect_tool()
    if tool.kind == 'unavailable' then
        return nil, tool.detail
    end
    local files = {}
    local total_bytes = 0
    local truncated = false
    local function add_file(file_path)
        -- fs_lstat (not fs_stat): symlinks are never followed for uploads.
        local file_stat = vim.uv.fs_lstat(file_path)
        if file_stat ~= nil and file_stat.type == 'file' then
            files[#files + 1] = { path = file_path, size = file_stat.size or 0 }
            total_bytes = total_bytes + (file_stat.size or 0)
        end
    end
    if stat.type == 'file' then
        add_file(abs)
    elseif stat.type == 'directory' then
        for name, entry_type in vim.fs.dir(abs, { depth = 20 }) do
            if #files >= WALK_FILES_MAX then
                truncated = true
                break
            end
            if entry_type == 'file' then
                add_file(vim.fs.joinpath(abs, name))
            end
        end
    else
        return nil, 'not a file or directory: ' .. path
    end
    if #files == 0 then
        return nil, 'nothing to upload under ' .. path
    end
    local argv = {}
    for _, word in ipairs(tool.prefix) do
        argv[#argv + 1] = word
    end
    argv[#argv + 1] = 'upload'
    argv[#argv + 1] = clean
    argv[#argv + 1] = abs
    return { argv = argv, files = files, total_bytes = total_bytes, truncated = truncated }, nil
end

---Preview lines for the upload dry-run float: the exact argv plus the
---file list with sizes.
---@param plan ai.huggingface.UploadPlan
---@return string[] lines
function M.upload_preview_lines(plan)
    local lines = { 'argv: ' .. table.concat(plan.argv, ' '), '' }
    for _, file in ipairs(plan.files) do
        lines[#lines + 1] = ('%10d  %s'):format(file.size, file.path)
    end
    lines[#lines + 1] = ''
    local note = ('%d file(s), %d bytes total'):format(#plan.files, plan.total_bytes)
    if plan.truncated then
        note = note .. (' (truncated at %d files)'):format(WALK_FILES_MAX)
    end
    lines[#lines + 1] = note
    return lines
end

---Upload with a dry-run preview first: the float shows the exact argv
---and every file with its size, and the spawn happens ONLY after the
---explicit vim.ui.select confirmation.
---@param local_path string File or directory to upload.
---@param repo string 'owner/name'.
---@param opts? { select_impl?: fun(items: string[], opts: table, on_choice: fun(choice: integer|nil)) }
---@return boolean ok
---@return ai.huggingface.TransferOutcome|string result_or_err
function M.upload(local_path, repo, opts)
    local plan, plan_err = M.upload_plan(local_path, repo)
    if plan_err ~= nil then
        return false, plan_err
    end
    assert(plan ~= nil, 'upload_plan returned no error but no plan')
    local pick = (opts and opts.select_impl) or M.config.select_impl or vim.ui.select
    local xet = maybe_ensure_hf_xet(pick)
    if xet == 'cancelled' then
        return false, 'cancelled'
    end
    open_float(M.upload_preview_lines(plan), ' hf upload dry-run ')
    local confirmed = false
    if M.config.confirm_upload then
        pick({ 'Upload now', 'Cancel' }, { prompt = 'Confirm upload:' }, function(choice)
            confirmed = choice == 1
        end)
    else
        confirmed = true
    end
    if not confirmed then
        return false, 'cancelled'
    end
    local result, exec_err = rce.safe_exec(plan.argv, { timeout_ms = M.config.timeout_ms })
    if exec_err ~= nil then
        return false, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return false, 'upload failed: ' .. vim.trim(result.stderr or result.stdout or '')
    end
    local stats = vim.trim((result.stdout or '') .. '\n' .. (result.stderr or ''))
    if stats == '' then
        stats = nil
    end
    return true, { stats = stats, xet = xet }
end

---:HfXetStatus lines: git-xet custom-transfer registration (module 1's
---git-xet work), hf-xet availability, and -- for a model repo -- the
---Hub xet-read-token probe. The probe reports only what the API
---exposes; anything undetermined says so plainly, never a guess.
---@param repo string|nil Optional 'owner/name' model repo to probe.
---@return string[] lines
function M.xet_status_lines(repo)
    local lines = { 'git-xet (module 1) registration:' }
    local result, exec_err = rce.safe_exec(
        { 'git', 'config', '--get-regexp', 'lfs.customtransfer' },
        { timeout_ms = 10000 }
    )
    if exec_err ~= nil or result == nil or result.code ~= 0 or vim.trim(result.stdout or '') == '' then
        lines[#lines + 1] = '  (no lfs.customtransfer agents registered)'
    else
        for _, line in ipairs(vim.split(vim.trim(result.stdout or ''), '\n', { plain = true })) do
            -- The value could theoretically carry anything; show the key only.
            lines[#lines + 1] = '  ' .. (line:match('^%S+') or line)
        end
    end
    local toolmgr = require('utils.toolmgr')
    local xet = toolmgr.check_binary({
        name = 'git-xet',
        version_argv = { 'git', 'xet', '--version' },
        min_version = XET_VERSION_KNOWN,
    })
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'hf-xet (Hub download path):'
    lines[#lines + 1] = '  '
        .. (M.hf_xet_present() and 'present' or 'absent')
        .. ' (pip package hf-xet; guided install: pip install "'
        .. M.config.hf_xet_package
        .. '")'
    lines[#lines + 1] = '  git-xet tool: ' .. xet.detail
    local trimmed = vim.trim(repo or '')
    if trimmed ~= '' then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Hub xet probe for ' .. trimmed .. ':'
        local clean, repo_err = validate_repo_id(trimmed)
        if repo_err ~= nil then
            lines[#lines + 1] = '  ' .. repo_err
        else
            assert(clean ~= nil, 'validate_repo_id returned no error but no id')
            local probe = hfapi.repo_xet_probe(clean, M.config)
            lines[#lines + 1] = '  ' .. probe.note
            if not probe.xet_enabled then
                lines[#lines + 1] = '  (the public Hub API exposes no xetEnabled flag; '
                    .. 'this probe is the token endpoint, which is the closest public signal)'
            end
        end
    else
        lines[#lines + 1] = ''
        lines[#lines + 1] = '(pass a model repo id to probe its Hub xet status: :HfXetStatus owner/name)'
    end
    return lines
end

---Per-aspect validation. Never throws and never errors: a missing tool
---is 'unavailable', a missing token is informational.
---@return ai.huggingface.Check[] checks
function M.checks()
    local checks = {}
    local tool = M.detect_tool()
    checks[#checks + 1] = {
        name = 'hf',
        status = tool.kind == 'unavailable' and 'unavailable' or 'ok',
        detail = tool.detail,
    }
    local hub_version = M.pip_package_version('huggingface_hub')
    checks[#checks + 1] = {
        name = 'huggingface_hub',
        status = hub_version ~= nil and 'ok' or 'unavailable',
        detail = hub_version ~= nil and ('python package ' .. hub_version)
            or 'not installed for ' .. M.config.python_bin,
    }
    checks[#checks + 1] = {
        name = 'hf-xet',
        status = M.hf_xet_present() and 'ok' or 'unavailable',
        detail = M.hf_xet_present() and 'pip package hf-xet present'
            or 'absent (guided install: pip install "' .. M.config.hf_xet_package .. '")',
    }
    local token = M.hf_token()
    checks[#checks + 1] = {
        name = 'HF_TOKEN',
        status = token ~= nil and 'ok' or 'unavailable',
        detail = token ~= nil and 'set (needed for private repos / upload)'
            or 'not set (informational only; public search works without it)',
    }
    local probe, probe_err = rce.safe_exec(
        { 'curl', '-sS', '-o', '/dev/null', '--max-time', '8', M.config.api_base .. '/api/models?limit=1' },
        { timeout_ms = 15000 }
    )
    local reachable = probe_err == nil and probe ~= nil and probe.code == 0
    checks[#checks + 1] = {
        name = 'network',
        status = reachable and 'ok' or 'unavailable',
        detail = reachable and (M.config.api_base .. ' reachable')
            or 'cannot reach ' .. M.config.api_base .. ' (best-effort probe)',
    }
    return checks
end

---@class ai.huggingface.UpdateOffer
---@field label string Human label, e.g. 'hf'.
---@field current_version string|nil Installed version (nil = not installed).
---@field latest string|nil Newest upstream version.
---@field known_upstream_version string Newest version this module knows about.
---@field update_choice string Label of the update action, e.g. 'Upgrade via pip (terminal)'.
---@field update fun() Runs the update action (explicit user choice only).
---@field migrations utils.toolmgr.Migration[]

---Compare installed/known/latest and offer update / migrate / skip.
---Mirrors the toolmgr.check_update dialog shape for the non-GitHub
---sources (hf standalone installer note, PyPI JSON).
---@param offer ai.huggingface.UpdateOffer
local function offer_update(offer)
    local toolmgr = require('utils.toolmgr')
    if offer.current_version == nil then
        vim.notify(offer.label .. ': not installed; nothing to update', vim.log.levels.WARN)
        return
    end
    if offer.latest == nil then
        vim.notify(offer.label .. ': release check failed', vim.log.levels.WARN)
        return
    end
    local latest = toolmgr.normalize_version(offer.latest)
    local current = toolmgr.normalize_version(offer.current_version)
    local known = toolmgr.normalize_version(offer.known_upstream_version)
    if latest == nil or current == nil or known == nil then
        vim.notify(offer.label .. ': unparseable version in comparison', vim.log.levels.WARN)
        return
    end
    local baseline = known
    if toolmgr.compare_versions(current, known) > 0 then
        baseline = current
    end
    if toolmgr.compare_versions(latest, baseline) <= 0 then
        vim.notify(('%s: up to date (%s; latest %s)'):format(offer.label, current, latest), vim.log.levels.INFO)
        return
    end
    local items = {
        offer.update_choice,
        'Apply config migrations for ' .. latest,
        'Skip',
    }
    local pick = M.config.select_impl or vim.ui.select
    pick(items, { prompt = ('%s %s -> %s:'):format(offer.label, current, latest) }, function(choice)
        if choice == 1 then
            offer.update()
        elseif choice == 2 then
            local applied, notes = toolmgr.apply_migrations(offer.migrations, current)
            vim.notify(
                ('%s: %d migration(s) applied\n%s'):format(offer.label, applied, table.concat(notes, '\n')),
                vim.log.levels.INFO
            )
        end
    end)
end

---Latest huggingface_hub version from the PyPI JSON API (verified live
---2026-09-27). Bounded curl, argv form.
---@return string|nil version
---@return string|nil err
local function pypi_latest_hub_version()
    local argv = {
        'curl',
        '-sS',
        '--max-time',
        '15',
        '--max-filesize',
        '262144',
        'https://pypi.org/pypi/huggingface_hub/json',
    }
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = 20000 })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'PyPI request failed: ' .. vim.trim(result.stderr or '')
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok or type(decoded) ~= 'table' then
        return nil, 'PyPI response did not decode as JSON'
    end
    local info = decoded.info
    if type(info) ~= 'table' or type(info.version) ~= 'string' or info.version == '' then
        return nil, 'PyPI response has no info.version'
    end
    return info.version, nil
end

---The three update flows: hf (GitHub releases of huggingface_hub, with
---the standalone-installer note since no package manager ships it),
---huggingface_hub (PyPI JSON), git-xet (toolmgr GitHub flow).
local function cmd_update_check()
    local toolmgr = require('utils.toolmgr')
    local tool = M.detect_tool()
    local hf_tag, hf_tag_err = toolmgr.github_latest_tag('huggingface/huggingface_hub')
    if hf_tag_err ~= nil then
        vim.notify('hf: release check failed: ' .. hf_tag_err, vim.log.levels.WARN)
    else
        offer_update({
            label = 'hf',
            current_version = tool.version,
            latest = hf_tag,
            known_upstream_version = HF_VERSION_KNOWN,
            update_choice = 'Show the standalone installer command',
            update = function()
                vim.notify(
                    'hf: no package manager ships the standalone CLI; run this yourself:\n'
                        .. 'curl -LsSf https://hf.co/cli/install.sh | bash',
                    vim.log.levels.INFO
                )
            end,
            migrations = MIGRATIONS_HF,
        })
    end
    local pypi_latest, pypi_err = pypi_latest_hub_version()
    if pypi_err ~= nil then
        vim.notify('huggingface_hub: PyPI check failed: ' .. pypi_err, vim.log.levels.WARN)
    else
        offer_update({
            label = 'huggingface_hub',
            current_version = M.pip_package_version('huggingface_hub'),
            latest = pypi_latest,
            known_upstream_version = HF_VERSION_KNOWN,
            update_choice = 'Upgrade via pip (opens a terminal)',
            update = function()
                vim.cmd('botright 15split')
                local buf = api.nvim_get_current_buf()
                vim.fn.termopen({ M.config.python_bin, '-m', 'pip', 'install', '-U', 'huggingface_hub' })
                api.nvim_buf_set_name(buf, 'huggingface://install/huggingface_hub')
            end,
            migrations = MIGRATIONS_HUB,
        })
    end
    toolmgr.check_update({
        tool_label = 'git-xet',
        repo = 'huggingface/xet-core',
        package = 'git-xet',
        current_version = toolmgr.command_version({ 'git', 'xet', '--version' }),
        known_upstream_version = XET_VERSION_KNOWN,
        migrations = MIGRATIONS_XET,
        select_impl = M.config.select_impl,
    })
end

---Detail float body for one search hit; models need the extra detail
---fetch (the list response has no lastModified), datasets and papers
---carry everything in the hit.
---@param kind 'models'|'datasets'|'papers'
---@param entry table One parsed entry.
---@return string[]|nil lines
---@return string|nil err
local function detail_lines(kind, entry)
    if kind == 'models' then
        local detail, err = hfapi.model_detail(entry.id, M.config)
        if err ~= nil then
            return nil, err
        end
        assert(detail ~= nil, 'model_detail returned no error but no detail')
        return hfapi.model_detail_lines(detail), nil
    elseif kind == 'datasets' then
        return hfapi.dataset_detail_lines(entry), nil
    else
        return hfapi.paper_detail_lines(entry), nil
    end
end

---:HfModels / :HfDatasets / :HfPapers -- search the Hub, pick from the
---formatted hits, show a detail float for the choice.
---@param kind 'models'|'datasets'|'papers'
---@param query string|nil Free-text query; blank lists.
local function cmd_search(kind, query)
    local entries, err = hfapi.search(kind, query, M.config)
    if err ~= nil then
        notify_failed('Hf' .. kind, err)
        return
    end
    if #entries == 0 then
        vim.notify('Hf' .. kind .. ': no results', vim.log.levels.INFO)
        return
    end
    local shown = {}
    for index = 1, math.min(#entries, M.config.results_max) do
        shown[#shown + 1] = entries[index]
    end
    local lines
    if kind == 'models' then
        lines = hfapi.model_picker_lines(shown)
    elseif kind == 'datasets' then
        lines = hfapi.dataset_picker_lines(shown)
    else
        lines = hfapi.paper_picker_lines(shown)
    end
    local pick = M.config.select_impl or vim.ui.select
    pick(lines, { prompt = 'Hugging Face ' .. kind .. ':' }, function(choice)
        if choice == nil or shown[choice] == nil then
            return
        end
        local detail, detail_err = detail_lines(kind, shown[choice])
        if detail_err ~= nil then
            notify_failed('Hf' .. kind .. ' detail', detail_err)
            return
        end
        assert(detail ~= nil, 'detail_lines returned no error but no lines')
        open_float(detail, ' ' .. kind .. ' detail ')
    end)
end

---:HfDownload <repo> [revision]
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_download(cmd_opts)
    local args = cmd_opts.fargs or {}
    local ok, outcome = M.download(args[1], args[2], {})
    if not ok then
        if outcome ~= 'cancelled' then
            notify_failed('HfDownload', outcome)
        end
        return
    end
    assert(type(outcome) == 'table', 'download returned ok but no outcome table')
    if outcome.stats ~= nil then
        local tail = vim.split(outcome.stats, '\n', { plain = true })
        local first = math.max(1, #tail - OUTPUT_TAIL_MAX + 1)
        local shown = {}
        for index = first, #tail do
            shown[#shown + 1] = tail[index]
        end
        open_float(shown, ' hf download ')
    else
        vim.notify('HfDownload: completed (the tool reported no transfer stats)', vim.log.levels.INFO)
    end
    if outcome.xet == 'no-xet' then
        vim.notify('HfDownload: standard transfer (hf-xet not installed)', vim.log.levels.WARN)
    end
end

---:HfUpload <local_path> <repo>
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_upload(cmd_opts)
    local args = cmd_opts.fargs or {}
    if #args < 2 then
        vim.notify('HfUpload: usage: HfUpload <local_path> <owner/repo>', vim.log.levels.ERROR)
        return
    end
    local ok, outcome = M.upload(args[1], args[2], {})
    if not ok then
        if outcome ~= 'cancelled' then
            notify_failed('HfUpload', outcome)
        else
            vim.notify('HfUpload: cancelled before any spawn', vim.log.levels.INFO)
        end
        return
    end
    assert(type(outcome) == 'table', 'upload returned ok but no outcome table')
    if outcome.stats ~= nil then
        local tail = vim.split(outcome.stats, '\n', { plain = true })
        local first = math.max(1, #tail - OUTPUT_TAIL_MAX + 1)
        local shown = {}
        for index = first, #tail do
            shown[#shown + 1] = tail[index]
        end
        open_float(shown, ' hf upload ')
    else
        vim.notify('HfUpload: completed (the tool reported no transfer stats)', vim.log.levels.INFO)
    end
    if outcome.xet == 'no-xet' then
        vim.notify('HfUpload: standard transfer (hf-xet not installed)', vim.log.levels.WARN)
    end
end

---:HfXetStatus [repo]
---@param cmd_opts table nvim_create_user_command callback options.
local function cmd_xet_status(cmd_opts)
    local repo = vim.trim(cmd_opts.args or '')
    if repo == '' then
        repo = nil
    end
    open_float(M.xet_status_lines(repo), ' hf xet status ')
end

---:HfValidate -- one vim.notify per check; missing tools say
---"unavailable", never an error; a missing HF_TOKEN is informational.
local function cmd_validate()
    for _, check in ipairs(M.checks()) do
        local level = vim.log.levels.INFO
        if check.status == 'unavailable' and check.name ~= 'HF_TOKEN' then
            level = vim.log.levels.WARN
        end
        vim.notify(('hf %-14s %-11s %s'):format(check.name, check.status, check.detail), level)
    end
end

---:HfDocs -- open the verified Hub API reference.
local function cmd_docs()
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('huggingface docs: ' .. url, vim.log.levels.INFO)
    end
end

---Register commands. Idempotent: commands are created once; the config
---is rebuilt on every call. Performs no subprocess I/O itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('HfModels', function(cmd_opts)
        cmd_search('models', cmd_opts.args)
    end, { nargs = '?', desc = 'Search Hugging Face models' })
    api.nvim_create_user_command('HfDatasets', function(cmd_opts)
        cmd_search('datasets', cmd_opts.args)
    end, { nargs = '?', desc = 'Search Hugging Face datasets' })
    api.nvim_create_user_command('HfPapers', function(cmd_opts)
        cmd_search('papers', cmd_opts.args)
    end, { nargs = '?', desc = 'Search Hugging Face papers' })
    api.nvim_create_user_command('HfDownload', cmd_download, {
        nargs = '+',
        desc = 'Download a Hub repo via the hf CLI (optional revision)',
    })
    api.nvim_create_user_command('HfUpload', cmd_upload, {
        nargs = '+',
        complete = 'file',
        desc = 'Upload a path to a Hub repo (dry-run preview + confirm)',
    })
    api.nvim_create_user_command('HfXetStatus', cmd_xet_status, {
        nargs = '?',
        desc = 'git-xet registration, hf-xet availability, Hub xet probe',
    })
    api.nvim_create_user_command('HfValidate', cmd_validate, { desc = 'Per-tool validation report' })
    api.nvim_create_user_command(
        'HfUpdateCheck',
        cmd_update_check,
        { desc = 'Update check for hf, huggingface_hub, git-xet' }
    )
    api.nvim_create_user_command('HfDocs', cmd_docs, { desc = 'Open the Hub API reference' })
end

return M
