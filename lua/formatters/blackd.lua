-- #################################################################
-- ~/.config/nvim/lua/formatters/blackd.lua
-- Native blackd Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://black.readthedocs.io/en/stable/usage_and_configuration/black_as_a_server.html
---
--- blackd is the Black formatter running as a tiny web server on your own
--- machine. Starting Black fresh for every format is slow; instead we mail
--- the code to the server with a web request and it mails the tidied code
--- back. Mirrors the inline blackd registration in init.lua.
---
--- We talk to it with `curl`: a POST request carrying the code on stdin,
--- with the `X-Protocol-Version: 1` header the server expects. The server
--- answers 200 with the tidied code, or 204 meaning "already tidy, here is
--- your code back unchanged". The `--write-out` trailer smuggles the HTTP
--- status code into stdout so `decode` below can read it. Only plain HTTP to
--- your own computer (127.0.0.1) is allowed, with short timeouts, so a hung
--- server can never freeze the editor.

---@param value any
---@return string
local function message(value)
    return tostring(value):gsub('[%z\1-\31\127]', ' '):sub(1, 4096)
end

---@return string[]
local function build_args()
    local runner = require('formatters')
    local url = runner.options.blackd_url
    local port_text = type(url) == 'string' and url:match('^http://127%.0%.0%.1:(%d+)/?$')
    local port = tonumber(port_text)
    assert(
        port ~= nil and port >= 1 and port <= 65535,
        'blackd_url must be an HTTP IPv4 loopback endpoint with a valid port'
    )
    return {
        '--disable',
        '--silent',
        '--show-error',
        '--noproxy',
        '*',
        '--proto',
        '=http',
        '--connect-timeout',
        '1',
        '--max-time',
        '10',
        '--request',
        'POST',
        '--header',
        'Content-Type: text/plain; charset=utf-8',
        '--header',
        'X-Protocol-Version: 1',
        '--data-binary',
        '@-',
        '--write-out',
        '\\nNVIM_FORMAT_HTTP:%{http_code}',
        url,
    }
end

---@param output string
---@param context FormatterContext
---@return string
local function decode(output, context)
    local body, code = output:match('^(.*)\nNVIM_FORMAT_HTTP:(%d%d%d)$')
    assert(code, 'Blackd response has no HTTP status')
    if code == '204' then
        return context.input
    end
    assert(code == '200', 'Blackd HTTP ' .. code .. ': ' .. message(body))
    return body
end

---@type FormatterSpec
return {
    cmd = 'curl',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'py',
    decode = decode,
}
