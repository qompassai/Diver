--- prng.lua — Non-crypto RNG detection for security-sensitive contexts.
---
--- Plain-language version: computers have two kinds of random number
--- generators. The fast one (like Math.random() in JavaScript) is fine
--- for games and shuffling playlists, but its output can be predicted
--- if an attacker sees enough of it. The secure one (like crypto.randomBytes)
--- is unpredictable even if an attacker watches it. This module is the
--- bouncer: it spots when the fast, predictable generator is used to
--- create things that must be unpredictable — session cookies, signing
--- keys, auth tokens, password salts. That exact mistake (CVE-2026-61500:
--- HFS seeded Koa's cookie signer with Math.random()) is under live attack.
---
--- Sources: CVE-2026-61500 (Rejetto HFS session-signing flaw, 2026-10-03),
--- OWASP "Insecure Randomness", CWE-338 (Use of Cryptographically Weak PRNG).
---@module 'security.prng'

local M = {}

local FINDINGS_MAX = 64 -- cap on scan findings returned.

---@class security.PrngFinding
---@field code string Stable finding code, e.g. 'prng.weak_in_signing'
---@field detail string Human-readable explanation.
---@field line integer 1-based line number of the match.
---@field severity 'low'|'medium'|'high'

-- Non-cryptographic RNG sources by language. These are fast but predictable;
-- an attacker who observes enough outputs can recover the internal state
-- (e.g. V8's xorshift128+ behind Math.random is fully reversible).
---@type { lang: string, pattern: string, why: string }[]
local WEAK_SOURCES = {
    { lang = 'c', pattern = '%srand%s*%(%s*%)', why = 'C rand() is predictable; use getrandom() or /dev/urandom' },
    { lang = 'go', pattern = 'rand%.Float64%s*%(', why = 'Go math/rand is predictable; use crypto/rand' },
    { lang = 'go', pattern = 'rand%.Intn%s*%(', why = 'Go math/rand is predictable; use crypto/rand' },
    { lang = 'java', pattern = 'Math%.random%s*%(%s*%)', why = 'Java Math.random is predictable; use SecureRandom' },
    { lang = 'java', pattern = 'new%s+Random%s*%(%s*%)', why = 'Java Random is predictable; use SecureRandom' },
    {
        lang = 'javascript',
        pattern = 'Math%.random%s*%(',
        why = 'V8 Math.random uses xorshift128+, fully reversible from observed outputs',
    },
    {
        lang = 'lua',
        pattern = 'math%.random%s*%(',
        why = 'Lua math.random is a PRNG, predictable from observed outputs',
    },
    {
        lang = 'python',
        pattern = 'random%.choice%s*%(',
        why = 'Python random module uses Mersenne Twister, predictable; use secrets module',
    },
    {
        lang = 'python',
        pattern = 'random%.randint%s*%(',
        why = 'Python random module uses Mersenne Twister, predictable; use secrets module',
    },
    {
        lang = 'python',
        pattern = 'random%.random%s*%(',
        why = 'Python random module uses Mersenne Twister, predictable; use secrets module',
    },
    { lang = 'ruby', pattern = '%srand%s*%(', why = 'Ruby rand uses PRNG, predictable; use SecureRandom' },
    { lang = 'ruby', pattern = 'Random%.rand%s*%(', why = 'Ruby Random uses PRNG, predictable; use SecureRandom' },
    {
        lang = 'rust',
        pattern = 'thread_rng%s*%(%s*%)',
        why = 'rand::thread_rng is not crypto-secure by default; use getrandom or ring',
    },
    {
        lang = 'typescript',
        pattern = 'Math%.random%s*%(',
        why = 'V8 Math.random uses xorshift128+, fully reversible from observed outputs',
    },
}

-- Security-sensitive sinks: contexts where the value MUST be unpredictable.
-- If a weak RNG feeds one of these, the result is forgeable.
---@type { code: string, pattern: string, why: string }[]
local SENSITIVE_SINKS = {
    {
        code = 'prng.weak_in_cookie',
        pattern = 'cookie',
        why = 'Cookie values from predictable RNG allow forgery',
    },
    {
        code = 'prng.weak_in_keygen',
        pattern = 'key',
        why = 'Cryptographic keys from predictable RNG are recoverable',
    },
    {
        code = 'prng.weak_in_nonce',
        pattern = 'nonce',
        why = 'Nonces from predictable RNG break replay protection',
    },
    {
        code = 'prng.weak_in_password',
        pattern = 'password',
        why = 'Password-related values from predictable RNG are guessable',
    },
    {
        code = 'prng.weak_in_salt',
        pattern = 'salt',
        why = 'Salts from predictable RNG weaken password hashing',
    },
    {
        code = 'prng.weak_in_secret',
        pattern = 'secret',
        why = 'Secrets from predictable RNG are recoverable',
    },
    {
        code = 'prng.weak_in_session',
        pattern = 'session',
        why = 'Session identifiers from predictable RNG allow session hijacking',
    },
    {
        code = 'prng.weak_in_signing',
        pattern = 'sign',
        why = 'Cookie/session signing with predictable RNG allows signature forgery (CVE-2026-61500)',
    },
    {
        code = 'prng.weak_in_token',
        pattern = 'token',
        why = 'Auth tokens from predictable RNG allow impersonation',
    },
}

---@param findings security.PrngFinding[]
---@param severity 'low'|'medium'|'high'
---@param code string
---@param line integer
---@param detail string
local function add_finding(findings, severity, code, line, detail)
    assert(type(findings) == 'table')
    assert(type(code) == 'string')
    assert(type(detail) == 'string')
    if #findings >= FINDINGS_MAX then
        return
    end
    findings[#findings + 1] = {
        code = code,
        detail = detail,
        line = line,
        severity = severity,
    }
end

---Scan text for weak RNG usage in security-sensitive contexts.
---Returns findings where a weak RNG source appears near a sensitive sink.
---@param text string The code to scan.
---@param opts? { lang?: string } Optional language filter.
---@return security.PrngFinding[] findings
function M.scan(text, opts)
    assert(type(text) == 'string')
    opts = opts or {}
    local findings = {}

    -- Split into lines for line-number reporting.
    local lines = {}
    for line in text:gmatch('[^\n]*') do
        lines[#lines + 1] = line
    end

    for i, line in ipairs(lines) do
        local lower = line:lower()

        -- Check each weak source.
        for _, src in ipairs(WEAK_SOURCES) do
            if opts.lang == nil or opts.lang == src.lang then
                if lower:find(src.pattern:lower()) then
                    -- Found a weak RNG. Now check if a sensitive sink is nearby
                    -- (same line, or within 3 lines for multi-line expressions).
                    local context_start = math.max(1, i - 3)
                    local context_end = math.min(#lines, i + 3)
                    for j = context_start, context_end do
                        local ctx_lower = lines[j]:lower()
                        for _, sink in ipairs(SENSITIVE_SINKS) do
                            if ctx_lower:find(sink.pattern) then
                                add_finding(
                                    findings,
                                    'high',
                                    sink.code,
                                    i,
                                    string.format(
                                        'Weak RNG (%s) near security-sensitive context "%s" at line %d: %s. %s',
                                        src.pattern,
                                        sink.pattern,
                                        j,
                                        sink.why,
                                        src.why
                                    )
                                )
                                break -- one finding per sink per line is enough
                            end
                        end
                    end
                end
            end
        end
    end

    return findings
end

---Scan a buffer for weak RNG issues.
---@param bufnr? integer Buffer number (default: current).
---@return security.PrngFinding[] findings
function M.scan_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    assert(type(bufnr) == 'number')
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    -- Map filetype to language for filtering.
    local lang_map = {
        c = 'c',
        go = 'go',
        java = 'java',
        javascript = 'javascript',
        lua = 'lua',
        python = 'python',
        ruby = 'ruby',
        rust = 'rust',
        typescript = 'typescript',
    }
    return M.scan(text, { lang = lang_map[ft] })
end

return M
