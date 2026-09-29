-- gates.lua
--
-- The three non-negotiable approval gates for the bug-bounty pipeline.
--
-- Plain language: some steps in bug hunting are dangerous (scanning someone
-- else's servers) or irreversible (sending a report). Each such step waits
-- behind a gate, and a gate opens only when a human operator approves it.
-- Approval is a file on disk -- no file, no go. Files are used instead of
-- memory so approvals survive restarts and stay auditable later.
--
-- The three gates (proposal section 11):
--   1. scope      -- open before ANY active scanning (recon.lua enforces this)
--   2. finding    -- open before a report is generated from a finding
--   3. submission -- open before a report payload is shown for submission
---@module 'security.bounty.gates'

local M = {}

local KINDS = {
    scope = true,
    finding = true,
    submission = true,
}

---Directory that holds all approval marker files.
---@return string
function M.root()
    return vim.fn.expand('~/security/bugbounties/gates')
end

---Validate a gate kind and target slug. Slugs are path-safe by construction.
---@param kind string One of 'scope', 'finding', 'submission'.
---@param target string Program or report slug; must be path-safe.
local function check_args(kind, target)
    assert(KINDS[kind], "gates: unknown gate kind '" .. tostring(kind) .. "'")
    assert(type(target) == 'string' and target ~= '', 'gates: target must be a nonempty string')
    assert(target:match('^[A-Za-z0-9_%.%-]+$'), 'gates: target must be path-safe (letters, digits, _, ., -)')
end

---Full path of the marker file for one gate.
---@param kind string Gate kind.
---@param target string Program or report slug.
---@return string
local function marker_path(kind, target)
    return M.root() .. '/' .. target .. '/' .. kind .. '.approved'
end

---Open a gate. This is the conscious human act -- nothing calls this
---automatically. Writes a marker file with a timestamp and optional note.
---@param kind string Gate kind.
---@param target string Program or report slug.
---@param note? string Why this was approved (recorded in the marker).
---@return string path The marker file written.
function M.approve(kind, target, note)
    check_args(kind, target)
    assert(note == nil or type(note) == 'string', 'gates.approve: note must be a string')
    local path = marker_path(kind, target)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    local lines = {
        'approved_at=' .. os.date('!%Y-%m-%dT%H:%M:%SZ'),
        'kind=' .. kind,
        'target=' .. target,
        'note=' .. (note or ''),
    }
    vim.fn.writefile(lines, path)
    return path
end

---Revoke (close) a gate by deleting its marker file.
---@param kind string Gate kind.
---@param target string Program or report slug.
---@return boolean removed True when a marker existed and was deleted.
function M.revoke(kind, target)
    check_args(kind, target)
    local path = marker_path(kind, target)
    if vim.uv.fs_stat(path) == nil then
        return false
    end
    vim.fn.delete(path)
    return true
end

---Is this gate currently open?
---@param kind string Gate kind.
---@param target string Program or report slug.
---@return boolean
function M.is_open(kind, target)
    check_args(kind, target)
    return vim.uv.fs_stat(marker_path(kind, target)) ~= nil
end

---Report the state of all three gates for one target.
---@param target string Program or report slug.
---@return { scope: boolean, finding: boolean, submission: boolean }
function M.status(target)
    assert(type(target) == 'string' and target ~= '', 'gates.status: target must be a nonempty string')
    return {
        scope = M.is_open('scope', target),
        finding = M.is_open('finding', target),
        submission = M.is_open('submission', target),
    }
end

return M
