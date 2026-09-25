--- Download guard — the "check the seal before you drink" rule.
---
--- Plain-language version: when Neovim downloads something from the internet,
--- a sneaky middleman on the network could swap the file for a bad one. This
--- module does two things about that. First, it only downloads over HTTPS
--- (never plain HTTP), and it tells curl to use modern TLS and to speak only
--- the HTTPS protocol, so the middleman cannot silently downgrade the
--- connection. Second, after the download it checks the file's fingerprint
--- (its SHA-256 checksum) against the fingerprint you expected. If even one
--- byte differs, the file is thrown away and never used.
---
--- Sources: curl manpage (https://curl.se/docs/manpage.html): --tlsv1.2
--- ("forces curl to use TLS version 1.2 or later"), --proto ("tells curl to
--- use the listed protocols for its initial retrieval", `=https` restricts to
--- HTTPS only), --pinnedpubkey ("tells curl to use the specified public key
--- ... to verify the peer"), --fail ("fail fast with no output on HTTP
--- errors").
---@module 'security.mitm'

local rce = require('security.rce')

local M = {}

local CURL_MAX_TIME_S = 120 -- hard ceiling on one curl invocation.
local DOWNLOAD_TIMEOUT_MS = 150000 -- bound on the whole download step.
local SHA256_HEX_LEN = 64 -- hex digits in a SHA-256 digest.
local HEX_DIGEST_PATTERN = '^(%x+)' -- leading hex run of a checksum line.

---@class security.MitmDownloadOptions
---@field timeout_ms? integer Max time to wait for curl (default 150000).
---@field pinned_pubkey? string Optional curl --pinnedpubkey value (SPKI pin) for certificate pinning.

---True when url uses the https scheme (case-insensitive, matching the
---scheme gate in verify_download). Plain http (and unknown schemes)
---are never acceptable for network downloads.
---@param url string
---@return boolean
function M.url_is_secure(url)
    return type(url) == 'string' and url:sub(1, 8):lower() == 'https://'
end

---@param url string
---@return string|nil scheme Lowercase scheme, or nil when url has none.
local function url_scheme(url)
    local scheme = url:match('^([%w][%w+.-]*)://')
    if scheme == nil then
        return nil
    end
    return scheme:lower()
end

---Pick a SHA-256 checksum tool available on this machine.
---@return string[]|nil hasher_argv argv prefix, or nil when none is installed.
local function find_hasher()
    if vim.fn.executable('sha256sum') == 1 then
        return { 'sha256sum' }
    end
    if vim.fn.executable('shasum') == 1 then
        return { 'shasum', '-a', '256' }
    end
    return nil
end

---Compute the SHA-256 hex digest of a file already on disk.
---@param path string
---@return string|nil digest Lowercase hex digest.
---@return string|nil err
local function sha256_file(path)
    local hasher_argv = find_hasher()
    if hasher_argv == nil then
        return nil, 'no SHA-256 tool found (need sha256sum or shasum)'
    end
    local argv = {}
    for index, part in ipairs(hasher_argv) do
        argv[index] = part
    end
    argv[#argv + 1] = path
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = 30000 })
    if exec_err ~= nil then
        return nil, 'checksum tool failed: ' .. exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'checksum tool exited with code ' .. result.code
    end
    local digest = (result.stdout or ''):match(HEX_DIGEST_PATTERN)
    if digest == nil or #digest ~= SHA256_HEX_LEN then
        return nil, 'could not parse checksum output'
    end
    return digest:lower(), nil
end

---@param value string
---@return boolean
local function is_sha256_hex(value)
    return type(value) == 'string' and #value == SHA256_HEX_LEN and value:match('^%x+$') ~= nil
end

---Download url to dest over a TLS-hardened curl invocation, then verify the
---file's SHA-256 digest against expected_sha256 *before* it is used. A
---mismatched file is deleted and never returned.
---
---Network downloads must be https:// (plaintext http is refused: a MITM can
---read and rewrite it). file:// URLs are allowed for local/testing use;
---they carry no network MITM risk but are still checksum-verified.
---@param url string
---@param expected_sha256 string 64 lowercase (or uppercase) hex digits.
---@param dest string Destination path the verified file is written to.
---@param opts? security.MitmDownloadOptions
---@return string|nil path dest on success.
---@return string|nil err Human-readable reason on expected failure.
function M.verify_download(url, expected_sha256, dest, opts)
    if type(url) ~= 'string' or url == '' then
        return nil, 'verify_download expects a non-empty url string'
    end
    if not is_sha256_hex(expected_sha256) then
        return nil, 'verify_download expects a 64-hex-digit SHA-256 digest'
    end
    if type(dest) ~= 'string' or dest == '' then
        return nil, 'verify_download expects a non-empty dest string'
    end
    opts = opts or {}

    local scheme = url_scheme(url)
    if scheme == 'http' then
        return nil, 'refusing plaintext http download (MITM risk): use https'
    end
    if scheme ~= 'https' and scheme ~= 'file' then
        return nil, 'refusing download with unsupported scheme: ' .. tostring(scheme)
    end

    -- argv form only: url and dest are never interpolated into a shell string.
    local argv = { 'curl', '--fail', '--silent', '--show-error', '--location' }
    if scheme == 'https' then
        -- Pin the connection to modern TLS and to the https protocol so a
        -- middleman cannot downgrade either.
        argv[#argv + 1] = '--tlsv1.2'
        argv[#argv + 1] = '--proto'
        argv[#argv + 1] = '=https'
        if opts.pinned_pubkey ~= nil then
            if type(opts.pinned_pubkey) ~= 'string' or opts.pinned_pubkey == '' then
                return nil, 'pinned_pubkey must be a non-empty string'
            end
            argv[#argv + 1] = '--pinnedpubkey'
            argv[#argv + 1] = opts.pinned_pubkey
        end
    end
    argv[#argv + 1] = '--max-time'
    argv[#argv + 1] = tostring(CURL_MAX_TIME_S)
    argv[#argv + 1] = '-o'
    argv[#argv + 1] = dest
    argv[#argv + 1] = url

    local timeout_ms = opts.timeout_ms or DOWNLOAD_TIMEOUT_MS
    local dl_result, exec_err = rce.safe_exec(argv, { timeout_ms = timeout_ms })
    if exec_err ~= nil then
        -- curl -o truncates/creates dest before the transfer completes, so a
        -- failed download can leave a partial, unchecked file behind. Remove
        -- the husk: only checksum-verified bytes may sit at dest.
        pcall(os.remove, dest)
        return nil, 'download failed: ' .. exec_err
    end
    assert(dl_result ~= nil, 'safe_exec returned no error but no result')
    if dl_result.code ~= 0 then
        -- A failed transfer must never be mistaken for a fresh download: a
        -- stale dest file from an earlier run would otherwise verify against
        -- its own old, valid checksum. curl left it untouched; remove it.
        pcall(os.remove, dest)
        return nil, 'download failed: curl exited with code ' .. dl_result.code
    end

    local digest, digest_err = sha256_file(dest)
    if digest_err ~= nil then
        pcall(os.remove, dest)
        return nil, digest_err
    end
    assert(digest ~= nil, 'sha256_file returned no error but no digest')
    if digest ~= expected_sha256:lower() then
        -- Do not leave a tampered file lying around for something else to use.
        pcall(os.remove, dest)
        return nil, 'checksum mismatch: downloaded file does not match expected SHA-256'
    end
    return dest, nil
end

return M
