-- Purpose: every knob for the BiDi track in one place. Driver binary
-- locations, pinned versions with SHA256 checksums (filled in by Matt
-- from the official release pages before first spawn -- empty means
-- "refuse to spawn"), ports, timeouts, and all size bounds as named
-- constants. Nothing here performs I/O.

local M = {}

---Driver pins. PROVISIONAL versions: re-verify against the vendor release
---pages on Matt's machine, then fill in the sha256 fields. An empty
---sha256 means driver.lua refuses to spawn and tells the user the exact
---download URL instead. Never auto-download.
---@class BidiDriverPin
---@field binary_names string[] executable names searched on PATH
---@field version string pinned vendor version
---@field url string exact download URL for the pinned version
---@field sha256 string expected SHA256 hex, or '' when unpinned
---@field port integer loopback port the driver is spawned on
---@field spawn_args string[] extra argv for the driver (no shell)

M.drivers = {
    chrome = {
        binary_names = { 'chromedriver' },
        version = '154.0.8037.57',
        url = 'https://storage.googleapis.com/chrome-for-testing-public/'
            .. '154.0.8037.57/linux64/chromedriver-linux64.zip',
        -- Verified 2026-09-27: downloaded from the URL above (official
        -- Chrome for Testing bucket; version pinned via the
        -- googlechromelabs.github.io/chrome-for-testing JSON API). CfT
        -- publishes no checksums, so provenance is HTTPS + version pin.
        sha256 = 'e2d9334f850f34e9dceba0c850903a5757b212062fefc9f3e2aa94c414a0ae96',
        port = 9515,
        spawn_args = { '--allowed-ips=127.0.0.1' },
    },
    firefox = {
        binary_names = { 'geckodriver' },
        version = '0.37.1',
        url = 'https://github.com/mozilla/geckodriver/releases/download/'
            .. 'v0.37.1/geckodriver-v0.37.1-linux64.tar.gz',
        -- Verified 2026-09-27: downloaded from the URL above (official
        -- mozilla/geckodriver release). Tarball byte size matched the
        -- GitHub API metadata exactly (2348355). The .asc signature names
        -- Mozilla's release key 09BEED63F3462A2DFFAB3B875ECB6497C1A20256,
        -- but the keyserver is unreachable from this sandbox, so GPG
        -- verification was not possible.
        sha256 = 'f831b7e61454804e8a307edd951bf8a5f373efe3f718e75454a6485a51f6e39f',
        port = 4444,
        spawn_args = { '--host', '127.0.0.1' },
    },
}

---Loopback host the driver HTTP endpoints are contacted on.
M.host = '127.0.0.1'

---HTTP handshake budget per request (driver /status poll and /session).
M.http_timeout_ms = 5000

---How many times to poll GET /status before the driver counts as failed.
M.ready_attempts_max = 50
---Pause between /status polls, milliseconds.
M.ready_poll_interval_ms = 200

---Cap on a single BiDi command payload handed to the transport.
M.command_bytes_max = 1048576

---Cap on a decoded screenshot PNG. A 4K PNG is a few MB; anything at or
---above this is treated as hostile or corrupt and rejected, never kept.
M.screenshot_bytes_max = 16777216 -- 16 MiB

---Depth bound for RemoteValue -> Lua conversion in script.lua.
M.remote_value_depth_max = 8
---Item bound for RemoteValue array/object conversion.
M.remote_value_items_max = 4096

---Max characters of a :BidiEval expression shown in the confirm prompt.
M.eval_preview_chars_max = 200

---Exact-match allowlist of pre-approved JS expressions. The only bypass
---for the per-invocation :BidiEval confirmation; empty by default.
---@type string[]
M.eval_allowlist = {}

---Extra directories searched for driver binaries before PATH.
---@type string[]
M.driver_search_dirs = {
    '/usr/local/bin',
    '/opt/homebrew/bin',
}

return M
