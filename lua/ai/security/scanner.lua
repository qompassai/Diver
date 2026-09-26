-- /qompassai/Diver/lua/ai/security/scanner.lua
-- Qompass AI Content Scanner (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Byte-level checks over file heads and text, run BEFORE content
-- enters AI context or gets executed. Covers magic-byte sniffing,
-- extension-vs-magic mismatch, polyglot markers, null bytes in text
-- files, PNG/JPEG metadata keyword heuristics, prompt-injection
-- patterns, zero-width obfuscation, and one-level base64
-- decode-and-rescan. Everything is bounded; the scanner only reads,
-- never executes. Metadata scanning is heuristic keyword matching,
-- not a real EXIF/chunk parse -- see the limits in
-- ai/security/init.lua.

local patterns = require('ai.security.patterns')

local M = {}

-- Named bounds (all in bytes unless the name says otherwise).
local MAGIC_READ_BYTES_MAX = 64
local FILE_READ_BYTES_MAX = 2 * 1024 * 1024
local META_SCAN_BYTES_MAX = 16384
local TEXT_SCAN_BYTES_MAX = 65536
local B64_RUN_MIN = 64
local B64_RUN_MAX = 32768
local DECODE_ATTEMPT_MAX = 8
local FINDING_COUNT_MAX = 128
-- Byte/text layer bounds (all in characters unless the name says otherwise).
local ROT13_RUN_MIN = 32
local HEX_RUN_MIN = 64
local GIBBERISH_TOKEN_MIN = 24
local GIBBERISH_SYMBOL_RATIO = 0.5

---@class SecurityFinding
---@field severity 'low'|'medium'|'high'
---@field code string Stable finding code
---@field detail string Human-readable explanation
---@field offset? integer 1-based byte offset in the scanned input

---@class SecurityReport
---@field verdict 'clean'|'suspicious'|'malicious'
---@field findings SecurityFinding[]

---@param findings SecurityFinding[]
---@param severity 'low'|'medium'|'high'
---@param code string
---@param detail string
---@param offset? integer
local function add_finding(findings, severity, code, detail, offset)
    assert(type(findings) == 'table')
    assert(type(code) == 'string')
    assert(type(detail) == 'string')
    if #findings >= FINDING_COUNT_MAX then
        return
    end
    findings[#findings + 1] = {
        severity = severity,
        code = code,
        detail = detail,
        offset = offset,
    }
end

-- Mach-O magic values (32-bit, 64-bit, fat binary, byte-swapped).
local MACHO_MAGICS = {
    '\254\237\250\206',
    '\254\237\250\207',
    '\202\254\186\190',
    '\206\250\237\254',
}

---@param head string First bytes of the file (up to MAGIC_READ_BYTES_MAX)
---@return string kind Sniffed kind: png|jpeg|gif|webp|bmp|elf|macho|zip|script|binary|text
local function detect_kind(head)
    assert(type(head) == 'string')
    if head:sub(1, 8) == '\137PNG\r\n\026\n' then
        return 'png'
    end
    if head:byte(1) == 255 and head:byte(2) == 216 and head:byte(3) == 255 then
        return 'jpeg'
    end
    if head:sub(1, 4) == 'GIF8' then
        return 'gif'
    end
    if head:sub(1, 4) == 'RIFF' and head:sub(9, 12) == 'WEBP' then
        return 'webp'
    end
    if head:sub(1, 2) == 'BM' then
        return 'bmp'
    end
    if head:sub(1, 4) == '\127ELF' then
        return 'elf'
    end
    for _, magic in ipairs(MACHO_MAGICS) do
        if head:sub(1, 4) == magic then
            return 'macho'
        end
    end
    if head:sub(1, 4) == 'PK\003\004' then
        return 'zip'
    end
    if head:sub(1, 2) == '#!' then
        return 'script'
    end
    if head:find('%z', 1, true) then
        return 'binary'
    end
    return 'text'
end

-- Expected sniffed kind per file extension (lowercased, no dot).
local EXPECTED_KIND = {
    png = 'png',
    jpg = 'jpeg',
    jpeg = 'jpeg',
    gif = 'gif',
    webp = 'webp',
    bmp = 'bmp',
    zip = 'zip',
}

local IMAGE_KINDS = {
    png = true,
    jpeg = true,
    gif = true,
    webp = true,
    bmp = true,
}

-- Extensions where a native executable is the honest content.
local EXECUTABLE_EXTS = {
    exe = true,
    so = true,
    dll = true,
    dylib = true,
    bin = true,
    elf = true,
    out = true,
}

-- Extensions treated as text for the null-byte check.
local TEXT_EXTS = {
    txt = true,
    md = true,
    markdown = true,
    lua = true,
    py = true,
    js = true,
    ts = true,
    json = true,
    yaml = true,
    yml = true,
    toml = true,
    sh = true,
    vim = true,
    c = true,
    h = true,
    cpp = true,
    rs = true,
    go = true,
    java = true,
    html = true,
    css = true,
    xml = true,
}

---@param kind string Sniffed kind from detect_kind
---@param ext string Lowercased extension without dot, '' if none
---@param findings SecurityFinding[]
local function check_magic_mismatch(kind, ext, findings)
    assert(type(kind) == 'string')
    assert(type(ext) == 'string')
    if kind == 'elf' or kind == 'macho' then
        -- A native executable wearing a non-executable extension is the
        -- classic "harmless document" trojan shape.
        if ext ~= '' and not EXECUTABLE_EXTS[ext] then
            local detail = 'Executable magic bytes but the extension claims .' .. ext
            add_finding(findings, 'high', 'binary.disguised_executable', detail)
        end
        return
    end
    if kind == 'zip' then
        if ext ~= '' and EXPECTED_KIND[ext] ~= 'zip' then
            local detail = 'Zip archive magic but the extension claims .' .. ext
            add_finding(findings, 'high', 'mismatch.archive_disguised', detail)
        end
        return
    end
    if kind == 'script' then
        if EXPECTED_KIND[ext] ~= nil and IMAGE_KINDS[EXPECTED_KIND[ext]] then
            local detail = '#! shebang but the extension claims an image (.' .. ext .. ')'
            add_finding(findings, 'high', 'polyglot.shebang_in_image', detail)
        end
        return
    end
    if IMAGE_KINDS[kind] then
        local expected = EXPECTED_KIND[ext]
        if expected ~= nil and expected ~= kind then
            local detail = 'Extension .' .. ext .. ' claims ' .. expected .. '; magic says ' .. kind
            add_finding(findings, 'medium', 'mismatch.extension_vs_magic', detail)
        end
        return
    end
    -- Extension claims an image but the magic bytes are something else
    -- entirely (text, binary). The classic "harmless picture" carrier for
    -- a payload the viewer never renders.
    local expected = EXPECTED_KIND[ext]
    if expected ~= nil and IMAGE_KINDS[expected] then
        local detail = 'Extension .' .. ext .. ' claims ' .. expected .. '; magic says ' .. kind
        add_finding(findings, 'medium', 'mismatch.extension_vs_magic', detail)
    end
end

-- Markers that turn an "image" into a polyglot: server code or markup
-- hiding in the byte stream after (or before) the image data.
local POLYGLOT_MARKERS = {
    { bytes = '<?php', code = 'polyglot.server_code', severity = 'high' },
    { bytes = '<script', code = 'polyglot.script_tag', severity = 'high' },
    { bytes = '<html', code = 'polyglot.html', severity = 'medium' },
    { bytes = '<%', code = 'polyglot.template_tag', severity = 'medium' },
}

---@param kind string Sniffed kind from detect_kind
---@param data string Bounded file content
---@param findings SecurityFinding[]
local function check_polyglot(kind, data, findings)
    assert(type(kind) == 'string')
    assert(type(data) == 'string')
    if not IMAGE_KINDS[kind] then
        return
    end
    local window = data:sub(1, TEXT_SCAN_BYTES_MAX)
    for _, marker in ipairs(POLYGLOT_MARKERS) do
        local pos = 1
        while pos <= #window do
            local start = window:find(marker.bytes, pos, true)
            if not start then
                break
            end
            local detail = 'Polyglot marker ' .. marker.bytes .. ' in ' .. kind .. ' bytes'
            add_finding(findings, marker.severity, marker.code, detail, start)
            pos = start + 1
        end
    end
end

---@param ext string Lowercased extension without dot
---@param data string Bounded file content
---@param findings SecurityFinding[]
local function check_null_bytes(ext, data, findings)
    assert(type(ext) == 'string')
    assert(type(data) == 'string')
    if not TEXT_EXTS[ext] then
        return
    end
    local start = data:find('%z', 1, true)
    if start then
        local detail = 'NUL byte in .' .. ext .. ' file: binary content hiding in text'
        add_finding(findings, 'medium', 'binary.null_byte_in_text', detail, start)
    end
end

---@param kind string Sniffed kind from detect_kind
---@param data string Bounded file content
---@param findings SecurityFinding[]
local function check_metadata(kind, data, findings)
    assert(type(kind) == 'string')
    assert(type(data) == 'string')
    if not IMAGE_KINDS[kind] then
        return
    end
    -- Heuristic only: we do NOT parse EXIF or walk PNG chunk lengths.
    -- We sweep the metadata region (file head) for ASCII keywords that
    -- look attack-shaped. A hit names the keyword and its offset; it
    -- does not prove the metadata is malicious.
    local window = data:sub(1, META_SCAN_BYTES_MAX):lower()
    for _, keyword in ipairs(patterns.metadata_keywords) do
        local start = window:find(keyword, 1, true)
        if start then
            local detail = 'Keyword "' .. keyword .. '" in ' .. kind .. ' metadata (heuristic)'
            add_finding(findings, 'low', 'metadata.suspicious_keyword', detail, start)
        end
    end
end

---@param text string Text to inspect
---@param findings SecurityFinding[]
---@return boolean zero_width_found
local function find_zero_width(text, findings)
    assert(type(text) == 'string')
    local found = false
    for _, entry in ipairs(patterns.zero_width) do
        local pos = 1
        while pos <= #text do
            local start = text:find(entry.bytes, pos, true)
            if not start then
                break
            end
            -- A U+FEFF at byte 1 is just a UTF-8 BOM, not obfuscation.
            if not (entry.name == 'U+FEFF' and start == 1) then
                local detail = 'Zero-width ' .. entry.name .. ': hidden text may be smuggled here'
                add_finding(findings, entry.severity, 'obfuscation.zero_width', detail, start)
                found = true
            end
            pos = start + 1
        end
    end
    return found
end

---@param text string Lowercased text is NOT required; lowering happens here
---@param findings SecurityFinding[]
---@return string[] codes Unique pattern codes that hit
local function scan_injection_patterns(text, findings)
    assert(type(text) == 'string')
    local lowered = text:lower()
    local codes = {}
    local seen = {}
    for _, entry in ipairs(patterns.injection_patterns) do
        local pos = 1
        while pos <= #lowered do
            local start = lowered:find(entry.pattern, pos)
            if not start then
                break
            end
            add_finding(findings, entry.severity, entry.code, entry.why, start)
            if not seen[entry.code] then
                seen[entry.code] = true
                codes[#codes + 1] = entry.code
            end
            pos = start + 1
        end
    end
    return codes
end

-- Base64 alphabet reversed into byte -> sextet value.
local B64_REVERSE = (function()
    local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local reverse = {}
    for index = 1, #alphabet do
        reverse[alphabet:byte(index)] = index - 1
    end
    return reverse
end)()

---@param run string Candidate base64 run (padding already validated by caller)
---@return string? decoded Decoded bytes, or nil when the run is not valid base64
local function b64_decode(run)
    assert(type(run) == 'string')
    local clean = run:gsub('=+$', '')
    local out = {}
    for index = 1, #clean, 4 do
        local a = B64_REVERSE[clean:byte(index)]
        local b = B64_REVERSE[clean:byte(index + 1)]
        local c = B64_REVERSE[clean:byte(index + 2)]
        local d = B64_REVERSE[clean:byte(index + 3)]
        if a == nil or b == nil then
            return nil
        end
        if d ~= nil and c == nil then
            return nil
        end
        out[#out + 1] = string.char(a * 4 + math.floor(b / 16))
        if c ~= nil then
            out[#out + 1] = string.char((b % 16) * 16 + math.floor(c / 4))
        end
        if d ~= nil then
            out[#out + 1] = string.char((c % 4) * 64 + d)
        end
    end
    return table.concat(out)
end

---@class B64Run
---@field start integer 1-based start offset of the run
---@field stop integer 1-based end offset of the run

---@param text string
---@return B64Run[] runs Candidate base64 runs worth decoding
local function find_b64_runs(text)
    assert(type(text) == 'string')
    local runs = {}
    local pos = 1
    while pos <= #text and #runs < DECODE_ATTEMPT_MAX * 2 do
        local start, stop = text:find('[A-Za-z0-9%+/=]+', pos)
        if not start then
            break
        end
        pos = stop + 1
        local run = text:sub(start, stop)
        if #run >= B64_RUN_MIN and #run <= B64_RUN_MAX then
            local body = run:gsub('=+$', '')
            local padding_ok = (#run - #body) <= 2
            if padding_ok and #body % 4 ~= 1 and body:match('^[A-Za-z0-9%+/]+$') then
                runs[#runs + 1] = { start = start, stop = stop }
            end
        end
    end
    return runs
end

---@param text string
---@param findings SecurityFinding[]
local function scan_base64(text, findings)
    assert(type(text) == 'string')
    local attempts = 0
    for _, run in ipairs(find_b64_runs(text)) do
        attempts = attempts + 1
        if attempts > DECODE_ATTEMPT_MAX then
            return
        end
        -- Exactly ONE decode level: the decoded bytes are re-scanned for
        -- injection patterns but never decoded again.
        local decoded = b64_decode(text:sub(run.start, run.stop))
        if decoded ~= nil and #decoded > 0 then
            local probe = {}
            local codes = scan_injection_patterns(decoded, probe)
            if #codes > 0 then
                for _, probe_finding in ipairs(probe) do
                    local inner = probe_finding.code .. ': ' .. probe_finding.detail
                    local detail = 'Base64 blob decodes to injection: ' .. inner
                    add_finding(findings, 'high', 'injection.base64_encoded', detail, run.start)
                end
            end
        end
    end
end

---@param findings SecurityFinding[]
---@return 'clean'|'suspicious'|'malicious'
local function verdict_for(findings)
    assert(type(findings) == 'table')
    local verdict = 'clean'
    for _, finding in ipairs(findings) do
        if finding.severity == 'high' then
            return 'malicious'
        end
        verdict = 'suspicious'
    end
    return verdict
end

-- Unicode TAG block (U+E0000-U+E007F) = UTF-8 F3 A0 80 80 - F3 A0 87 BF.
-- These characters render as nothing but survive copy/paste and model
-- tokenizers, so they can hide tool-metadata payloads inside plain words.
-- A Feb-May 2026 campaign used U+E0020 to split keywords like "funding",
-- making the approval view and the executed content differ.
--- "Unicode TAG-Block Concealment of Tool-Metadata Payloads in the Model
---   Context Protocol: An Approval-View Fidelity Gap Across Three
---   Independent Server Implementations" -- Mohammadreza Rashidi (2026),
---   arXiv:2607.05744, https://arxiv.org/abs/2607.05744
local TAG_BLOCK_PATTERN = '\243\160[\128-\135][\128-\191]'

---@param byte integer? Byte value, or nil past the string edge
---@return boolean alnum True for ASCII letters and digits
local function is_ascii_alnum(byte)
    if byte == nil then
        return false
    end
    return (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
end

---@param text string Original (non-lowercased) text; offsets are byte offsets
---@param findings SecurityFinding[]
local function find_tag_block(text, findings)
    assert(type(text) == 'string')
    local pos = 1
    while pos <= #text do
        local start = text:find(TAG_BLOCK_PATTERN, pos)
        if not start then
            break
        end
        -- Byte offsets, not char offsets: the 4-byte sequence occupies
        -- start..start+3, so the neighbors are start-1 and start+4.
        local before = text:byte(start - 1)
        local after = text:byte(start + 4)
        local detail
        if is_ascii_alnum(before) and is_ascii_alnum(after) then
            detail = 'Unicode TAG-block char (U+E0000-U+E007F) splitting a keyword invisibly: '
                .. 'ASCII alphanumerics on both sides of the 4-byte sequence'
        else
            detail = 'Unicode TAG-block char (U+E0000-U+E007F): invisible metadata may be hidden here'
        end
        add_finding(findings, 'high', 'unicode.tag_block', detail, start)
        pos = start + 1
    end
end

---@class BidiEntry
---@field bytes string Lua pattern matching one bidi char's UTF-8 bytes
---@field name string Unicode range label for the finding detail

---@type BidiEntry[]
local BIDI_ENTRIES = {
    -- U+202A-U+202E: explicit embedding/override controls.
    { bytes = '\226\128[\170-\174]', name = 'U+202A-U+202E' },
    -- U+2066-U+2069: isolate controls.
    { bytes = '\226\129[\166-\169]', name = 'U+2066-U+2069' },
}

-- Bidirectional controls reorder displayed text, so what the user reads is
-- not what the model tokenizes -- the classic Trojan-Source shape applied
-- to prompt content. Same arXiv:2607.05744 citation as the TAG block.
---@param text string Original (non-lowercased) text
---@param findings SecurityFinding[]
local function find_bidi_override(text, findings)
    assert(type(text) == 'string')
    for _, entry in ipairs(BIDI_ENTRIES) do
        local pos = 1
        while pos <= #text do
            local start = text:find(entry.bytes, pos)
            if not start then
                break
            end
            local detail = 'Bidirectional control ' .. entry.name .. ': display order can hide the true text'
            add_finding(findings, 'high', 'unicode.bidi_override', detail, start)
            pos = start + 1
        end
    end
end

---@param run string Lowercased ASCII alpha run
---@return string decoded ROT13-decoded run
local function rot13_decode(run)
    assert(type(run) == 'string')
    return (
        run:gsub('[a-z]', function(char)
            local byte = char:byte()
            assert(byte ~= nil)
            return string.char(((byte - 97 + 13) % 26) + 97)
        end)
    )
end

-- ROT13 layer: long alpha runs are ROT13-decoded and rescanned with the
-- injection patterns. Exactly ONE decode level, mirroring the base64
-- bound -- decoded output is never decoded again. Part of the framing-gap
-- detection: encoded exfil instructions are the framing gap's delivery
-- vehicle (arXiv:2608.27092). Honest limit: decoded alpha runs are
-- spaceless, so only single-token patterns (jailbreak, exfiltrat, ...) can
-- hit -- multi-word patterns with %s+ never match a spaceless run.
---@param text string Original text; lowering happens here
---@param findings SecurityFinding[]
local function scan_rot13_layer(text, findings)
    assert(type(text) == 'string')
    local lowered = text:lower()
    local pos = 1
    while pos <= #lowered do
        local start, stop = lowered:find('[a-z]+', pos)
        if not start then
            break
        end
        pos = stop + 1
        if stop - start + 1 >= ROT13_RUN_MIN then
            local decoded = rot13_decode(lowered:sub(start, stop))
            local probe = {}
            scan_injection_patterns(decoded, probe)
            for _, probe_finding in ipairs(probe) do
                local inner = probe_finding.code .. ' (' .. probe_finding.detail .. ')'
                local detail = 'rot13-encoded block decodes to: ' .. inner
                add_finding(findings, 'high', 'injection.framing_gap', detail, start)
            end
        end
    end
end

---@param run string Lowercased hex run with even length
---@return string? decoded Decoded bytes, or nil when a pair is not valid hex
local function hex_decode(run)
    assert(type(run) == 'string')
    local out = {}
    for index = 1, #run, 2 do
        local value = tonumber(run:sub(index, index + 1), 16)
        if value == nil then
            return nil
        end
        out[#out + 1] = string.char(value)
    end
    return table.concat(out)
end

-- Hex layer: maximal hex runs of 64+ chars are pair-decoded and rescanned
-- with the injection patterns, one level only (mirror of the base64
-- bound). MCPXKIT catalogs hex wrapping as a standard MCP
-- payload-obfuscation layer.
--- "MCPXKIT: The Unified Toolkit for Analyzing Model Context Protocol
---   Security" -- Yongjian Guo, Puzhuo Liu, Wanlun Ma, et al. (2025),
---   arXiv:2508.12538, https://arxiv.org/abs/2508.12538
---@param text string Original text; lowering happens here
---@param findings SecurityFinding[]
local function scan_hex_layer(text, findings)
    assert(type(text) == 'string')
    local lowered = text:lower()
    local pos = 1
    while pos <= #lowered do
        local start, stop = lowered:find('[0-9a-f]+', pos)
        if not start then
            break
        end
        pos = stop + 1
        if stop - start + 1 >= HEX_RUN_MIN then
            -- An odd-length run has a dangling nibble; drop it rather than
            -- rejecting the whole run.
            local even = lowered:sub(start, stop - (stop - start + 1) % 2)
            local decoded = hex_decode(even)
            if decoded ~= nil and #decoded > 0 then
                local probe = {}
                local codes = scan_injection_patterns(decoded, probe)
                if #codes > 0 then
                    local detail = 'hex-encoded layer decodes to: ' .. table.concat(codes, ', ')
                    add_finding(findings, 'high', 'encoding.hex_payload', detail, start)
                end
            end
        end
    end
end

-- GCG-style gibberish suffix: a long token (>= 24 chars) that is mostly
-- symbol bytes (> 50%). Thresholds are tunable heuristics, not measured
-- optima -- see arXiv:2606.10525 for the attack shape this approximates.
--- "Assessing Automated Prompt Injection Attacks in Agentic Environments"
---   -- David Hofer, Edoardo Debenedetti, Florian Tramer (2026),
---   arXiv:2606.10525, https://arxiv.org/abs/2606.10525
---@param text string Original text
---@param findings SecurityFinding[]
local function scan_gibberish(text, findings)
    assert(type(text) == 'string')
    local pos = 1
    while pos <= #text do
        local start, stop = text:find('%S+', pos)
        if not start then
            break
        end
        pos = stop + 1
        local token = text:sub(start, stop)
        if #token >= GIBBERISH_TOKEN_MIN then
            local _, symbol_count = token:gsub('[!-/:-@%[-`{-~]', '')
            if symbol_count / #token > GIBBERISH_SYMBOL_RATIO then
                local detail = 'gcg-like gibberish suffix: long token with high symbol density'
                add_finding(findings, 'medium', 'injection.gibberish_suffix', detail, start)
            end
        end
    end
end

---@param text string Text to scan (bounded by the caller)
---@return SecurityReport report
function M.scan_text(text)
    assert(type(text) == 'string')
    local findings = {}
    local zero_width_found = find_zero_width(text, findings)
    local codes = scan_injection_patterns(text, findings)
    -- Invisible characters next to an injection pattern stop being a
    -- curiosity: the pairing is the obfuscation technique working.
    if zero_width_found and #codes > 0 then
        for _, finding in ipairs(findings) do
            if finding.code == 'obfuscation.zero_width' then
                finding.severity = 'high'
                local paired = ' (paired with: ' .. table.concat(codes, ', ') .. ')'
                finding.detail = finding.detail .. paired
            end
        end
    end
    scan_base64(text, findings)
    find_tag_block(text, findings)
    find_bidi_override(text, findings)
    scan_rot13_layer(text, findings)
    scan_hex_layer(text, findings)
    scan_gibberish(text, findings)
    return { verdict = verdict_for(findings), findings = findings }
end

---@class ScanBytesOpts
---@field extension? string Lowercased extension without dot, '' if none
---@field filename? string Display name used in finding details

---@param data string Bounded file content (see FILE_READ_BYTES_MAX)
---@param opts? ScanBytesOpts
---@return SecurityReport report
function M.scan_bytes(data, opts)
    assert(type(data) == 'string')
    assert(opts == nil or type(opts) == 'table')
    local extension = (opts and opts.extension) or ''
    assert(type(extension) == 'string')
    local head = data:sub(1, MAGIC_READ_BYTES_MAX)
    local kind = detect_kind(head)
    local findings = {}
    check_magic_mismatch(kind, extension, findings)
    check_polyglot(kind, data, findings)
    check_null_bytes(extension, data, findings)
    check_metadata(kind, data, findings)
    local text_report = M.scan_text(data:sub(1, TEXT_SCAN_BYTES_MAX))
    for _, finding in ipairs(text_report.findings) do
        add_finding(findings, finding.severity, finding.code, finding.detail, finding.offset)
    end
    return { verdict = verdict_for(findings), findings = findings }
end

-- Re-exported so tests and callers can size their own reads.
M.FILE_READ_BYTES_MAX = FILE_READ_BYTES_MAX

return M
