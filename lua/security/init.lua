--- Security toolkit — the "seatbelts and smoke detectors" for this config.
---
--- Plain-language version: Neovim is powerful -- it can run programs,
--- download files, and install plugins from the internet. Powerful tools need
--- safety gear. This is the safety-gear box, with these tools inside:
---
---   security.rce         refuses shell-injection when running programs,
---   security.mitm        checks downloads are really what they claim to be,
---   security.zombie      keeps background jobs from piling up unnoticed,
---   security.supplychain checks installed plugins match the lockfile list.
---   security.blue      blue-team utilities (base64, gpg, sops, ssh, dap),
---   security.red       red-team utilities (config audits, wireshark, tomcat).
---   security.container Dockerfile/compose templates and audit commands.
---
--- Call require('security').setup() once from init.lua. Calling setup() again
--- is harmless. M.audit() runs every check that is safe to run headless and
--- hands back one report table.
---@module 'security'

local ai_sec = require('security.ai')
local blue = require('security.blue')
local bounty = require('security.bounty')
local container = require('security.container')
local ghidra = require('security.ghidra')
local mitm = require('security.mitm')
local rce = require('security.rce')
local red = require('security.red')
local supplychain = require('security.supplychain')
local zombie = require('security.zombie')

local M = {}

M.bounty = bounty
M.blue = blue
M.container = container
M.ghidra = ghidra
M.mitm = mitm
M.rce = rce
M.red = red
M.supplychain = supplychain
M.zombie = zombie

local AUGROUP_NAME = 'diver_security'
local COMMAND_NAME = 'SecurityAudit'

local setup_done = false

local ghidra_tool_detail = 'registration not attempted yet'
local ghidra_tool_status = 'skip'

---Register ghidra_analyze with the ai.harness tool registry, through
---the harness's own register_tool surface, when the harness is already
---set up. Producers share the harness's one registry instance; there
---is no second registry and no global. Never raises: the outcome is
---kept for the audit report -- 'pass' once registered, 'skip' while
---the harness is not up (a legitimate state: the harness starts on
---demand), 'fail' when the harness is up but registration is rejected.
local function register_ghidra_tool()
    if ghidra_tool_status == 'pass' then
        return
    end
    local ok, harness = pcall(require, 'ai.harness')
    if not ok or type(harness) ~= 'table' or type(harness.register_tool) ~= 'function' then
        ghidra_tool_status = 'skip'
        ghidra_tool_detail = 'ai.harness unavailable; ghidra_analyze not registered'
        return
    end
    local registered, err = harness.register_tool('ghidra_analyze', {
        description = 'Headless Ghidra analysis of a binary (functions, strings, decompile preview)',
        input_schema = {
            path = { required = true, type = 'string' },
            timeout_ms = { required = false, type = 'integer' },
        },
        risk = 'process',
        run = function(args)
            return ghidra.analyze(args.path, { timeout_ms = args.timeout_ms })
        end,
    })
    if registered then
        ghidra_tool_status = 'pass'
        ghidra_tool_detail = 'ghidra_analyze registered with the ai.harness tool registry'
    elseif harness._state == nil then
        ghidra_tool_status = 'skip'
        ghidra_tool_detail = 'ai harness not set up; ghidra_analyze not registered'
    else
        ghidra_tool_status = 'fail'
        ghidra_tool_detail = 'ghidra_analyze registration rejected: ' .. tostring(err)
    end
end

---@class security.AuditOptions
---@field download? { url: string, sha256: string, dest: string } Optional download to verify (skipped when absent).
---@field root? string Config root for the supply-chain check (default: cwd).

---Run every check that is safe headless and return one report table.
---Side effects: none, except an optional download verification when
---opts.download is supplied and the idempotent ghidra_analyze
---harness-tool registration attempt. Zombie jobs are listed, never
---killed, here.
---@param opts? security.AuditOptions
---@return { at: integer, checks: { name: string, status: string, detail: string }[], ok: boolean }
function M.audit(opts)
    opts = opts or {}
    ---@type { name: string, status: string, detail: string }[]
    local checks = {}
    local all_ok = true

    local function record(name, status, detail)
        checks[#checks + 1] = { name = name, status = status, detail = detail }
        if status == 'fail' then
            all_ok = false
        end
    end

    -- RCE self-test: the guard must flag a known-bad string and must refuse
    -- to run a string command. (A full-config sink scan is a separate job.)
    local findings, scan_err = rce.scan_string('$(touch /tmp/pwned)')
    local _, exec_err = rce.safe_exec('echo hi')
    if scan_err == nil and findings ~= nil and #findings > 0 and exec_err ~= nil then
        record('rce', 'pass', 'scan_string flags $(...); safe_exec refuses string commands')
    else
        record('rce', 'fail', 'self-test failed: scan_err=' .. tostring(scan_err))
    end

    -- MITM: only runs when the caller names an explicit download target.
    local download = opts.download
    if download == nil then
        record('mitm', 'skip', 'no download target supplied; pass opts.download to verify one')
    else
        local _, dl_err = mitm.verify_download(download.url, download.sha256, download.dest)
        if dl_err == nil then
            record('mitm', 'pass', 'downloaded and checksum-verified: ' .. download.dest)
        else
            record('mitm', 'fail', dl_err)
        end
    end

    -- Zombie: report, do not kill. Killing belongs to an explicit reap().
    local pruned = zombie.prune()
    record('zombie', 'pass', ('%d tracked job(s), %d dead entr(ies) pruned'):format(zombie.count(), pruned))

    -- Supply chain: read-only lockfile comparison.
    local sc_report = supplychain.verify_lockfile({ root = opts.root })
    if sc_report.ok then
        record(
            'supplychain',
            'pass',
            ('lockfiles in sync (%d pack, %d lazy entries checked)'):format(
                sc_report.pack_lock.checked,
                sc_report.lazy_lock.checked
            )
        )
    else
        record(
            'supplychain',
            'fail',
            ('desync=%d missing=%d errors=%d unpinned=%d'):format(
                #sc_report.pack_lock.desync,
                #sc_report.pack_lock.missing,
                #sc_report.pack_lock.errors,
                #sc_report.lazy_lock.unpinned
            )
        )
    end

    -- Ghidra: presence probe only. Absence is a legitimate state (the tool
    -- is optional), so it records 'skip' rather than 'fail' when missing.
    local ghidra_status = ghidra.status()
    if ghidra_status.available then
        record(
            'ghidra',
            'pass',
            ('headless available: %s (version %s)'):format(
                tostring(ghidra_status.analyze_headless),
                ghidra_status.version or 'unknown'
            )
        )
    else
        record('ghidra', 'skip', tostring(ghidra_status.error))
    end

    -- Ghidra harness tool: (re)attempt registration so a harness started
    -- after security.setup() still picks the tool up, then report the
    -- recorded outcome in the same pass/skip shape as the probe above.
    register_ghidra_tool()
    record('ghidra_tool', ghidra_tool_status, ghidra_tool_detail)

    -- Blue team: the subtree init loads its leaves and runs their setups
    -- at require time; the merged sops config proves that wiring ran.
    -- The kit is optional, so absence records 'skip', never 'fail'.
    local blue_sops = package.loaded['security.blue.sops']
    if type(blue_sops) == 'table' and type(blue_sops.config) == 'table' then
        record('blue', 'pass', 'blue-team leaves loaded; sops/ssh/dap setups applied')
    else
        record('blue', 'skip', 'security.blue not loaded')
    end

    -- Container: the module self-wires its Dockerfile/compose BufNewFile
    -- autocmds and the :DockerAudit/:DockerScan commands at require time,
    -- so its presence in package.loaded proves the wiring ran. The kit is
    -- optional, so absence records 'skip', never 'fail'.
    local container_mod = package.loaded['security.container']
    if type(container_mod) == 'table' and type(container_mod.audit_dockerfile) == 'function' then
        record('container', 'pass', 'container checks loaded (Dockerfile autocmds and commands registered)')
    else
        record('container', 'skip', 'security.container not loaded')
    end

    -- Red team: the checks are loaded but never run by the audit itself
    -- (they walk the config tree and open the quickfix list when invoked
    -- explicitly through security.red.red).
    local red_leaf = package.loaded['security.red.red']
    if type(red_leaf) == 'table' and type(red_leaf.run_all) == 'function' then
        record('red', 'pass', 'red-team checks loaded (run_all available; not run by audit)')
    else
        record('red', 'skip', 'security.red not loaded')
    end

    return { ok = all_ok, at = os.time(), checks = checks }
end

---Wire up the security toolkit. Idempotent: the second and later calls are
---no-ops returning the same module table.
---@param opts? table Reserved for future options; currently unused.
---@return table M
function M.setup(opts)
    if setup_done then
        return M
    end
    assert(opts == nil or type(opts) == 'table', 'security.setup expects an options table')
    vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
    vim.api.nvim_create_user_command(COMMAND_NAME, function()
        local report = M.audit()
        local lines = { ('SecurityAudit: %s'):format(report.ok and 'PASS' or 'FAIL') }
        for _, check in ipairs(report.checks) do
            lines[#lines + 1] = ('  [%s] %s: %s'):format(check.status, check.name, check.detail)
        end
        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, { desc = 'Run the diver security audit (security.* checks)' })
    -- Bug-bounty pipeline commands (:Bounty*). Idempotent; creates only
    -- user commands and the ~/security/bugbounties working dirs.
    bounty.setup()
    ghidra.setup()
    register_ghidra_tool()
    require('security.guard').setup()
    require('security.mask').setup()
    require('security.pass').setup()
    require('security.sshfs').setup()
    setup_done = true
    return M
end

-- AI security API (moved from ai.security): re-exported so AI modules
-- and general callers share one security namespace.
M.allowlist_add = ai_sec.allowlist_add
M.allowlist_check = ai_sec.allowlist_check
M.allowlist_load = ai_sec.allowlist_load
M.allowlist_save = ai_sec.allowlist_save
M.check_sampling_request = ai_sec.check_sampling_request
M.confirm_tool_call = ai_sec.confirm_tool_call
M.quarantine = ai_sec.quarantine
M.scan_file = ai_sec.scan_file
M.scan_text = ai_sec.scan_text

-- Submodules (also available as require('security.<name>')).
M.ai = ai_sec
M.annotations = require('security.annotations')
M.auditlog = require('security.auditlog')
M.commands = require('security.commands')
M.guard = require('security.guard')
M.mask = require('security.mask')
M.mcp_vet = require('security.mcp_vet')
M.patterns = require('security.patterns')
M.pqc = require('security.pqc')
M.prng = require('security.prng')
M.scanner = require('security.scanner')
M.token = require('security.token')

return M
