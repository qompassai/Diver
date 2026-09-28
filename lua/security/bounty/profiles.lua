-- profiles.lua
--
-- Program profiles: named rulebooks for bug-bounty programs, stored as pure
-- data. Loading or viewing a profile NEVER opens a scope gate, NEVER starts
-- a scan, and touches no network -- this module spawns no subprocesses and
-- performs no I/O except reading/writing its own small state files under
-- ~/security/bugbounties/profiles/. Profiles inform two later decisions:
-- validate_scope_request (is this scope-gate request acceptable under the
-- program's rules?) and check_recon_plan (does this recon plan violate the
-- program's prohibitions?). The human operator still opens every gate by
-- hand; selecting a profile is choosing a rulebook, not granting permission.
--
-- Plain language: every bounty program has its own rulebook -- what you may
-- touch, what you must never do. This module files those rulebooks where
-- Neovim can read them. Picking a rulebook off the shelf is not permission
-- to test anything; it only tells the later checks which rules to enforce.
---@module 'security.bounty.profiles'

local scope = require('security.bounty.scope')

local M = {}

---Boundaries for every scan and buffer in this module.
local TARGET_COUNT_MAX = 10000
local TARGET_LEN_MAX = 253 -- Longest legal DNS name; generous for URLs/CIDRs.
local PROFILE_NAME_MAX = 64
local CONFIRM_LINE_MAX = 512

---Path-safe pattern shared with gates.lua/scope.lua.
local PATH_SAFE = '^[A-Za-z0-9_%.%-]+$'

---@class security.bounty.Profile
---@field name string Registry key, e.g. 'dod-vdp'.
---@field display_name string Human-readable program name.
---@field platform string Platform hosting the program.
---@field program_type string e.g. 'VDP (response policy; no bounties)'.
---@field policy_url string URL the policy was ingested from.
---@field fetched_date string ISO date the policy text was ingested.
---@field source_hash string sha256 of the ingested source file.
---@field scope_model 'class'|'enumerated' How the policy expresses scope.
---@field scope_in string[] In-scope classes, in the policy's own words.
---@field scope_out string[] Out-of-scope classes, in the policy's own words.
---@field methods_allowed string[] Allowed method classes, policy's own words.
---@field methods_prohibited string[] Prohibited conduct, policy's own words.
---@field rate_limits string Policy's own words, or 'NOT IN POLICY'.
---@field testing_windows string Policy's own words, or 'NOT IN POLICY'.
---@field disclosure_terms string[] Disclosure rules, policy's own words.
---@field safe_harbor string Safe-harbor text (NOT a grant of authorization).
---@field slas string[] Response-time commitments, policy's own words.
---@field participation_requirements string[] Gates to participation.
---@field recon_blocked_tools string[] Recon stage names hard-blocked here.
---@field recon_cautions table<string,string> Stage -> caution text.
---@field vendor_markers string[] Heuristic third-party domain suffixes.
---@field notes string[] Operational notes (re-ingest, automation risk...).

---The registry. Pure data; add future programs by adding entries here.
---Each entry quotes the program's own policy -- fields the policy does not
---address are marked NOT IN POLICY and must not be read as permitted.
M.registry = {
    ['dod-vdp'] = {
        name = 'dod-vdp',
        display_name = 'U.S. Dept Of Defense',
        platform = 'HackerOne',
        program_type = 'VDP (response policy; no bounties)',
        policy_url = 'https://hackerone.com/DeptOfDefense',
        fetched_date = '2026-09-28',
        -- Computed 2026-09-28 from ~/workspace/bug-bounty/dod-vdp-profile.lua.
        source_hash = '01390aa8762906d29bcc8282d91504295a35124c808ba66d67242885fac30130',
        -- CLASS-BASED: the policy names no domains. Scope is a set of asset
        -- classes (DoD-owned/operated/controlled, publicly accessible). No
        -- enumerated domain list may ever be derived from the policy wording.
        scope_model = 'class',
        scope_in = {
            [[Publicly accessible information systems, web property, or data
owned, operated, or controlled by DoD.]],
            [[Footnote: DoD interprets "publicly accessible" as the means of
accessing "Information systems," as defined by 6 U.S.C. 1501(9) and
44 U.S.C. 3502, whereby a researcher has complied with all stated
limitations of activity under the guidelines of the VDP policy.]],
        },
        scope_out = {
            [[To the extent that any security research or vulnerability
disclosure activity involves the networks, systems, information,
applications, products, or services of a non-DoD entity (e.g., other
Federal departments or agencies; State, local, or tribal governments;
private sector companies or persons; employees or personnel of any such
entities; or any other such third party), that non-DoD entity may
independently determine whether to pursue legal action or remedies
related to such activities.]],
            [[Vendor systems are NOT authorized for testing under this VDP:
submitted information may be used to remediate vulnerabilities in DoD
networks or in vendor applications, but scope covers
DoD-owned/operated/controlled assets only. Report vendor issues to the
vendor per their own policy.]],
            [[Anything not publicly accessible is out of scope by definition.]],
        },
        methods_allowed = {
            [[(1) Testing, through remote means, to detect a vulnerability or
identify an indicator related to a vulnerability; and]],
            [[(2) Sharing information solely with DoD or receiving information
from DoD about a vulnerability or an indicator related to a
vulnerability.]],
            [[Exploitation is bounded, not banned: do no harm and do not
exploit any vulnerability beyond the minimal amount of testing required
to prove that a vulnerability exists or to identify an indicator
related to a vulnerability.]],
        },
        methods_prohibited = {
            [[You will not exfiltrate any data under any circumstances.]],
            [[You will not conduct denial of service testing.]],
            [[You will not conduct physical testing (e.g. office access, open
doors, tailgating) or social engineering, including spear phishing,
concerning DoD personnel or contractors.]],
            [[You will avoid intentionally accessing the content of any
communications, data, or information transiting or stored on a DoD
information system or systems -- except to the extent that the
information is directly related to a vulnerability and the access is
necessary to prove that the vulnerability exists.]],
            [[You will not intentionally compromise the privacy or safety of
DoD personnel (e.g., civilian employees or military members), or any
third parties.]],
            [[You will not intentionally compromise the intellectual property
or other commercial or financial interests of any DoD personnel or
entities, or any third parties.]],
            [[If during your research you are inadvertently exposed to
information that the public is not authorized to access, you will
effectively and permanently erase all identified information in your
possession as directed by DoD and report to DoD that you have done so.]],
            [[You will not submit a high-volume of low-quality reports.]],
        },
        rate_limits = 'NOT IN POLICY -- the policy states no numeric rate limits.',
        testing_windows = 'NOT IN POLICY -- the policy states no testing windows.',
        disclosure_terms = {
            [[You will not publicly disclose any details of the vulnerability,
indicator of vulnerability, or the content of information rendered
available by a vulnerability, except upon receiving express written
authorization from DoD.]],
            [[Public disclosure of vulnerabilities will only be authorized by
the express written consent of DoD.]],
            [[Public credit is possible but gated: DoD will seek to allow
researchers desiring public recognition, when practicable and
authorized.]],
            [[Submission consent: you consent to having the contents of the
communication and follow-up communications stored on a U.S. Government
information system.]],
        },
        safe_harbor = [[This policy does not grant authorization, permission,
or otherwise allow express or implied access to DoD information systems
to any individual, group of individuals, consortium, partnership, or any
other business or legal entity. However, if a security researcher working
in accordance with the terms and conditions of this VDP program discloses
a vulnerability, then DoD will, in the exercise of its authorities: (1)
not initiate or recommend any law enforcement action or civil lawsuits
related to such activities against that researcher, and (2) inform the
pertinent law enforcement agencies or civil plaintiffs that the
researcher's activities were, to the best of our knowledge, conducted
pursuant to, and in compliance with, the terms and conditions of the
program.]],
        slas = {
            [[Within one business day, DoD will acknowledge receipt of your
report. DoD's security team will investigate the report and may contact
you for further information.]],
            [[When practicable and authorized, DoD will confirm the existence
of the vulnerability to the researcher and keep the researcher informed,
as appropriate, while remediation of the vulnerability is under way.]],
        },
        participation_requirements = {
            [[Before participating in the VDP, conducting any testing of DoD
networks and prior to submitting a report, you must agree to abide by
these terms and conditions.]],
            [[Every report must include: type of issue; product, version, and
configuration of software containing the bug; step-by-step instructions
to reproduce the issue; proof-of-concept; impact of the issue; and
suggested mitigation or remediation actions, as appropriate.]],
            [[If questions arise, take no action until that action is
discussed with the VDP lead at the Department of Defense Cyber Crime
Center (DC3).]],
            [[If at any point you are uncertain whether to continue testing,
engage with their team.]],
            [[EXTERNAL (not in policy text; verified separately 2026-09-28):
a HackerOne account is required to submit. Veriff ID verification is
required for paid programs only; this VDP is exempt.]],
        },
        -- No current recon stage maps to a prohibited method class. If a
        -- stage is ever added that exfiltrates, DoSes, or phishes, its name
        -- goes here and check_recon_plan hard-blocks it.
        recon_blocked_tools = {},
        recon_cautions = {
            naabu = 'Port scanning is "testing through remote means", but the VDP demands'
                .. ' minimal testing and do-no-harm. Keep port sets small.',
            nuclei = 'Active vulnerability scanning must stay minimal. A high volume of low-quality'
                .. ' reports is prohibited; tune templates and scope tightly.',
            katana = 'Crawling accesses content. The policy forbids accessing content not directly'
                .. ' related to proving a vulnerability; stay on the confirmed target.',
            ffuf = 'Content discovery is high-risk under the minimal-testing rule. Keep wordlists'
                .. ' small, targeted, and rate-limited.',
        },
        -- Heuristic tripwire, NOT a classifier: domain suffixes that are
        -- definitionally third-party platforms. A match hard-blocks the
        -- target; the operator attestation below remains the real control.
        -- This list is operator-visible data: removing a marker is a
        -- conscious, diff-visible act, and that is the override path for a
        -- false positive (e.g. a DoD-owned asset behind a cloud domain).
        vendor_markers = {
            'amazonaws.com',
            'cloudfront.net',
            'azurewebsites.net',
            'cloudapp.azure.com',
            'googleapis.com',
            'appspot.com',
            'cloudfunctions.net',
            'cloudrun.net',
            'herokupapp.com',
            'vercel.app',
            'netlify.app',
            'github.io',
            'gitlab.io',
            'salesforce.com',
            'force.com',
            'servicenow.com',
            'sharepoint.com',
            'office365.com',
            'zendesk.com',
            'hubspot.com',
        },
        notes = {
            [[Defensive use only: information submitted under this program is
used to mitigate or remediate vulnerabilities in DoD networks or
applications, or in vendor applications. This research does not
contribute to offensive tools or capabilities.]],
            [[AUTOMATED SCANNING is not explicitly addressed in the policy.
"Testing through remote means" is permitted but constrained by
do-no-harm, minimal testing, and the low-quality-report ban. Treat
aggressive automated scanning as HIGH-RISK; confirm with the DC3 VDP
lead before heavy scanning.]],
            [[National-security context: DoD systems can have a life-or-death
impact on Service Members and partners of the United States. Extra care
is not optional here.]],
            [[Policy volatility: DoD may modify the terms and conditions or
terminate the program at any time. RE-INGEST the policy before every
cycle.]],
            [[Remediation timing caveat: it may take longer than expected to
remediate some vulnerabilities, as DoD must take extra care with these
systems (combat-zone / life-or-death context).]],
            [[The policy's enforcement assurances do not themselves grant
authorization: the safe harbor is a commitment not to pursue, not a
grant of access.]],
        },
    },
}

---Directory holding profile state: the active-profile marker and
---per-program target confirmations.
---@return string
function M.dir()
    return vim.fn.expand('~/security/bugbounties/profiles')
end

---@return string
local function active_path()
    return M.dir() .. '/active'
end

---@return string
local function confirmations_path(program)
    return M.dir() .. '/confirmations/' .. program .. '.txt'
end

---Sorted registry keys. Deterministic order for display and tests.
---@return string[]
function M.list()
    local names = {}
    for name, _ in pairs(M.registry) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---Fetch one profile. Returns nil + error for unknown names; loading a
---profile never opens any gate.
---@param name string Registry key.
---@return security.bounty.Profile|nil profile
---@return string|nil err
function M.get(name)
    if type(name) ~= 'string' or name == '' then
        return nil, 'profiles.get: name must be a nonempty string'
    end
    local profile = M.registry[name]
    if profile == nil then
        return nil, ("profiles.get: unknown profile '%s' (see :BountyProfile list)"):format(name)
    end
    return profile, nil
end

---Name of the currently active profile, or nil when none is set.
---The active profile only selects which rulebook later checks enforce;
---it is NOT an approval and opens no gate.
---@return string|nil name
function M.active()
    if vim.uv.fs_stat(active_path()) == nil then
        return nil
    end
    local lines = vim.fn.readfile(active_path())
    local name = lines[1]
    if name == nil or M.registry[name] == nil then
        return nil
    end
    return name
end

---Set the active profile. Validates the name is registered. This is
---explicitly NOT a gate: no approval is recorded, no scanning is enabled.
---@param name string Registry key.
---@return boolean ok
---@return string|nil err
function M.set(name)
    local _, err = M.get(name)
    if err ~= nil then
        return false, err
    end
    vim.fn.mkdir(M.dir(), 'p')
    vim.fn.writefile({ name }, active_path())
    return true, nil
end

---Clear the active profile.
---@return boolean cleared True when a profile had been set.
function M.clear()
    if vim.uv.fs_stat(active_path()) == nil then
        return false
    end
    vim.fn.delete(active_path())
    return true
end

---Validate a program slug (path-safe: it becomes a filename).
---@param program string
---@return boolean ok
---@return string|nil err
local function check_program(program)
    if type(program) ~= 'string' or program == '' then
        return false, 'program must be a nonempty string'
    end
    if #program > PROFILE_NAME_MAX then
        return false, 'program slug too long'
    end
    if not program:match(PATH_SAFE) then
        return false, 'program must be path-safe (letters, digits, _, ., -)'
    end
    return true, nil
end

---Validate a concrete target: nonempty, bounded, no whitespace/control.
---Targets may be domains, wildcards, URLs, or CIDRs, so the check stays
---syntactic -- semantic confirmation is the operator's job.
---@param target string
---@return boolean ok
---@return string|nil err
local function check_target(target)
    if type(target) ~= 'string' or target == '' then
        return false, 'target must be a nonempty string'
    end
    if #target > TARGET_LEN_MAX then
        return false, ("target too long (%d > %d)"):format(#target, TARGET_LEN_MAX)
    end
    if target:find('[%s%c]') then
        return false, 'target must not contain whitespace or control characters'
    end
    return true, nil
end

---Operator confirmation: record that a human attested this concrete target
---is a publicly accessible system owned, operated, or controlled by the
---program's owner -- and NOT a vendor or other out-of-scope system.
---Idempotent: confirming twice records once.
---@param program string Program slug.
---@param target string Concrete target, e.g. 'example.mil'.
---@return boolean ok
---@return string|nil err
function M.confirm_target(program, target)
    local ok_program, program_err = check_program(program)
    if not ok_program then
        return false, 'profiles.confirm_target: ' .. program_err
    end
    local ok_target, target_err = check_target(target)
    if not ok_target then
        return false, 'profiles.confirm_target: ' .. target_err
    end
    local path = confirmations_path(program)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    for _, existing in ipairs(M.confirmed_targets(program)) do
        if existing == target then
            return true, nil
        end
    end
    local line = target .. '\t' .. os.date('!%Y-%m-%dT%H:%M:%SZ') .. '\toperator-attested'
    vim.fn.writefile({ line }, path, 'a')
    return true, nil
end

---Targets the operator has confirmed for one program.
---@param program string Program slug.
---@return string[] targets
function M.confirmed_targets(program)
    local targets = {}
    if vim.uv.fs_stat(confirmations_path(program)) == nil then
        return targets
    end
    for _, line in ipairs(vim.fn.readfile(confirmations_path(program))) do
        local target = line:match('^([^\t]+)')
        if target ~= nil and #line <= CONFIRM_LINE_MAX then
            targets[#targets + 1] = target
        end
    end
    return targets
end

---Reduce a scope target to a comparable host: strip scheme, path, port,
---and a leading wildcard; lowercase.
---@param target string
---@return string host
local function target_host(target)
    local host = target:gsub('^%*%.', '')
    host = host:gsub('^https?://', ''):gsub('/.*$', ''):gsub(':%d+$', '')
    return host:lower()
end

---Does this target hit a vendor/non-DoD marker? Returns the marker or nil.
---@param profile security.bounty.Profile
---@param target string
---@return string|nil marker
local function vendor_marker_hit(profile, target)
    local host = target_host(target)
    for _, marker in ipairs(profile.vendor_markers or {}) do
        if host == marker or host:sub(-#marker - 1) == '.' .. marker then
            return marker
        end
    end
    return nil
end

---Validate a scope-gate request against a profile's load-bearing rules.
---Called BEFORE a scope gate may open. Returns ok=false plus every problem
---found (not just the first), so the operator sees the full picture.
---
---For class-based profiles (dod-vdp): the policy names no domains, so an
---enumerated target list can only come from the operator -- and every
---concrete target must carry an explicit operator confirmation attesting
---program ownership. Vendor/non-DoD markers hard-block.
---@param name string Registry key of the active profile.
---@param program string Program slug requesting the scope gate.
---@return boolean ok
---@return string[] problems Empty when ok.
function M.validate_scope_request(name, program)
    local problems = {}
    local profile, err = M.get(name)
    if profile == nil then
        return false, { err }
    end
    local ok_program, program_err = check_program(program)
    if not ok_program then
        return false, { 'profiles.validate_scope_request: ' .. program_err }
    end
    local loaded, entries = pcall(scope.load, program)
    if not loaded then
        return false, {
            ("no filed scope for '%s' (run :BountyScope first)"):format(program),
        }
    end
    assert(type(entries) == 'table', 'profiles: scope.load returned non-table')
    if #entries == 0 then
        return false, { ("filed scope for '%s' is empty; nothing to approve"):format(program) }
    end
    if #entries > TARGET_COUNT_MAX then
        return false, {
            ("filed scope for '%s' has %d targets (max %d); split it first"):format(
                program,
                #entries,
                TARGET_COUNT_MAX
            ),
        }
    end
    if profile.scope_model == 'class' then
        local confirmed = {}
        for _, t in ipairs(M.confirmed_targets(program)) do
            confirmed[t] = true
        end
        for _, entry in ipairs(entries) do
            local target = entry.target
            local marker = vendor_marker_hit(profile, target)
            if marker ~= nil then
                local block = "HARD BLOCK: '%s' matches vendor marker '%s'."
                    .. ' Vendor/non-DoD systems: NO safe harbor under this VDP.'
                    .. ' Report vendor issues to the vendor, never here.'
                problems[#problems + 1] = block:format(target, marker)
            elseif not confirmed[target] then
                local unconfirmed = "unconfirmed target '%s' under profile '%s'."
                    .. ' The policy lists no domains: every target needs operator'
                    .. ' confirmation (:BountyProfile confirm %s %s).'
                problems[#problems + 1] = unconfirmed:format(target, name, program, target)
            end
        end
    end
    if #problems > 0 then
        return false, problems
    end
    return true, {}
end

---Review a planned recon run against a profile's prohibitions. Call before
---any recon stage runs. Hard-blocks stages mapped to prohibited method
---classes; surfaces cautions (minimal-testing, content-access, automation
---risk) and the policy re-ingest nudge as warnings.
---@param name string Registry key of the active profile.
---@param stage_names string[] Planned recon stage names.
---@return boolean ok
---@return string[] problems Empty when ok.
---@return string[] warnings Non-blocking cautions.
function M.check_recon_plan(name, stage_names)
    local problems, warnings = {}, {}
    local profile, err = M.get(name)
    if profile == nil then
        return false, { err }, warnings
    end
    assert(type(stage_names) == 'table', 'profiles.check_recon_plan: stage_names must be a table')
    local blocked = {}
    for _, tool in ipairs(profile.recon_blocked_tools or {}) do
        blocked[tool] = true
    end
    for _, stage in ipairs(stage_names) do
        if blocked[stage] then
            local msg = "HARD BLOCK: recon stage '%s' is blocked under profile '%s'."
            problems[#problems + 1] = msg:format(stage, name)
        end
        local caution = (profile.recon_cautions or {})[stage]
        if caution ~= nil then
            warnings[#warnings + 1] = ("stage '%s': %s"):format(stage, caution)
        end
    end
    local reingest = 'policy re-ingest: data ingested %s (sha256 %s); DoD may modify the terms'
        .. ' at any time -- re-ingest the policy before each cycle'
    warnings[#warnings + 1] = reingest:format(profile.fetched_date, profile.source_hash:sub(1, 12))
    if #problems > 0 then
        return false, problems, warnings
    end
    return true, problems, warnings
end

---Append wrapped text to a line list, splitting embedded newlines.
---@param out string[]
---@param text string
local function add_text(out, text)
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line
    end
end

---Render a profile as buffer lines. Pure: no gates, no network, no I/O
---beyond the registry table. This is the read-only viewing path.
---@param name string Registry key.
---@return string[]|nil lines
---@return string|nil err
function M.render(name)
    local profile, err = M.get(name)
    if profile == nil then
        return nil, err
    end
    local out = {}
    local function header(title)
        out[#out + 1] = ''
        out[#out + 1] = '-- ' .. title .. ' --'
    end
    local function bullets(entries)
        for _, entry in ipairs(entries) do
            out[#out + 1] = '-'
            add_text(out, '  ' .. entry)
        end
    end
    out[#out + 1] = ('PROGRAM PROFILE: %s (%s)'):format(profile.display_name, profile.name)
    out[#out + 1] = '[READ-ONLY] Viewing this profile opens no gates and starts no scans.'
    out[#out + 1] = ('Policy: %s'):format(profile.policy_url)
    out[#out + 1] = ('Type: %s via %s'):format(profile.program_type, profile.platform)
    out[#out + 1] = ('Policy ingested: %s (source sha256 %s)'):format(
        profile.fetched_date,
        profile.source_hash:sub(1, 12)
    )
    out[#out + 1] = ('Scope model: %s'):format(profile.scope_model:upper())
    if profile.scope_model == 'class' then
        out[#out + 1] =
            'The policy names no domains. Never derive an enumerated domain list from the'
        out[#out + 1] =
            'policy wording: every concrete target needs explicit operator confirmation.'
    end
    header('SCOPE: IN')
    bullets(profile.scope_in)
    header('SCOPE: OUT')
    bullets(profile.scope_out)
    header('METHODS ALLOWED')
    bullets(profile.methods_allowed)
    header('METHODS PROHIBITED')
    bullets(profile.methods_prohibited)
    header('RATE LIMITS / TESTING WINDOWS')
    out[#out + 1] = '- ' .. profile.rate_limits
    out[#out + 1] = '- ' .. profile.testing_windows
    header('SLAS')
    bullets(profile.slas)
    header('PARTICIPATION REQUIREMENTS')
    bullets(profile.participation_requirements)
    header('DISCLOSURE TERMS')
    bullets(profile.disclosure_terms)
    header('SAFE HARBOR (a commitment not to pursue -- NOT a grant of authorization)')
    out[#out + 1] = '-'
    add_text(out, '  ' .. profile.safe_harbor)
    header('VENDOR / NON-DOD MARKERS (heuristic tripwire; hard-blocks on match)')
    for _, marker in ipairs(profile.vendor_markers or {}) do
        out[#out + 1] = '- *.' .. marker
    end
    header('OPERATIONAL NOTES')
    bullets(profile.notes)
    return out, nil
end

return M
