--- Security toolkit — the "seatbelts and smoke detectors" for this config.
---
--- Plain-language version: Neovim is powerful -- it can run programs,
--- download files, and install plugins from the internet. Powerful tools need
--- safety gear. This is the safety-gear box, with four tools inside:
---
---   security.rce         refuses shell-injection when running programs,
---   security.mitm        checks downloads are really what they claim to be,
---   security.zombie      keeps background jobs from piling up unnoticed,
---   security.supplychain checks installed plugins match the lockfile list.
---
--- Call require('security').setup() once from init.lua. Calling setup() again
--- is harmless. M.audit() runs every check that is safe to run headless and
--- hands back one report table.
---@module 'security'

local rce = require('security.rce')
local mitm = require('security.mitm')
local zombie = require('security.zombie')
local supplychain = require('security.supplychain')

local M = {}

M.rce = rce
M.mitm = mitm
M.zombie = zombie
M.supplychain = supplychain

local AUGROUP_NAME = 'diver_security'
local COMMAND_NAME = 'SecurityAudit'

local setup_done = false

---@class security.AuditOptions
---@field root? string Config root for the supply-chain check (default: cwd).
---@field download? { url: string, sha256: string, dest: string } Optional download to verify (skipped when absent).

---Run every check that is safe headless and return one report table.
---Side effects: none, except an optional download verification when
---opts.download is supplied. Zombie jobs are listed, never killed, here.
---@param opts? security.AuditOptions
---@return { ok: boolean, at: integer, checks: { name: string, status: string, detail: string }[] }
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
    setup_done = true
    return M
end

return M
