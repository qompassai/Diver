#!/usr/bin/env lua5.1

-- gitlabduo_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--
-- GitLab Duo LSP configuration with OAuth device authorization.
--
-- Commands:
--   :LspGitLabDuoSignIn
--   :LspGitLabDuoSignOut
--   :LspGitLabDuoStatus

local api = vim.api
local fn = vim.fn
local fs = vim.fs

local CONFIGURATION_METHOD = 'workspace/didChangeConfiguration'

local DEVICE_POLL_ATTEMPT_COUNT_MAX = 60
local DEVICE_POLL_INTERVAL_SECONDS_DEFAULT = 5
local DEVICE_POLL_INTERVAL_SECONDS_MIN = 1
local HTTP_TIMEOUT_SECONDS = 30
local HTTP_TIMEOUT_MS = 30000
local TOKEN_EXPIRY_BUFFER_SECONDS = 60

---@class GitLabDuoConfig
---@field client_id string
---@field gitlab_url string
---@field scopes string
---@field token_file string

---@class GitLabDuoHttpResponse
---@field body string
---@field status number

---@class GitLabDuoProcessResult
---@field code? number
---@field signal? number
---@field stderr? string
---@field stdout? string

---@class GitLabDuoToken
---@field access_token string
---@field expires_in number
---@field refresh_token? string
---@field saved_at? number
---@field token_type? string

---@class GitLabDuoDeviceAuthorization
---@field device_code string
---@field expires_in? number
---@field interval? number
---@field user_code string
---@field verification_uri string
---@field verification_uri_complete? string

---@class GitLabDuoOAuthError
---@field error? string
---@field error_description? string

---@class GitLabDuoTokenCheckPayload
---@field message? string
---@field reason? string

---@class GitLabDuoFeatureCheckPayload
---@field id? string
---@field message? string

---@class GitLabDuoFeatureStatePayload
---@field checks? table<integer, GitLabDuoFeatureCheckPayload>
---@field state? string

---@type GitLabDuoConfig
local config = {
  client_id = '00bb391f527d2e77b3467b0b6b900151cc6a28dcfb18fa1249871e43bc3e5832',
  gitlab_url = 'https://gitlab.com',
  scopes = 'api',
  token_file = fs.joinpath(fn.stdpath('data'), 'gitlab_duo_oauth.json'),
}

---@param value any
---@return boolean
local function is_integer(value)
  if type(value) ~= 'number' then
    return false
  end

  if value ~= value then
    return false
  end

  if value == math.huge then
    return false
  end

  if value == -math.huge then
    return false
  end

  return math.floor(value) == value
end

---@param value number
---@return integer
local function to_integer(value)
  assert(type(value) == 'number')
  assert(value == value)
  assert(value ~= math.huge)
  assert(value ~= -math.huge)

  local integer_value = math.floor(value)

  ---@cast integer_value integer

  return integer_value
end

---@param message string
---@param level integer
local function notify(message, level)
  assert(type(message) == 'string')
  assert(type(level) == 'number')
  assert(math.floor(level) == level)

  vim.notify(message, level, {
    title = 'GitLab Duo',
  })
end

---@param value string
---@return string
local function form_encode(value)
  assert(type(value) == 'string')

  local encoded = value:gsub('([^%w%-_%.~])', function(character)
    return string.format('%%%02X', string.byte(character))
  end)

  return encoded
end

---@param values table<string, string>
---@return string
local function encode_form(values)
  assert(type(values) == 'table')

  local keys = vim.tbl_keys(values)

  table.sort(keys)

  local fragments = {}

  for index = 1, #keys do
    local key = keys[index]
    local value = values[key]

    assert(type(key) == 'string')
    assert(type(value) == 'string')

    fragments[#fragments + 1] = form_encode(key) .. '=' .. form_encode(value)
  end

  return table.concat(fragments, '&')
end

---@param body string
---@param status number
---@return GitLabDuoHttpResponse
local function new_http_response(body, status)
  assert(type(body) == 'string')
  assert(type(status) == 'number')

  ---@type GitLabDuoHttpResponse
  local response = {
    body = body,
    status = status,
  }

  return response
end

---@param output string
---@return GitLabDuoHttpResponse
local function parse_curl_output(output)
  assert(type(output) == 'string')

  local body, status_text = output:match('^(.*)\n(%d%d%d)$')

  if body == nil then
    return new_http_response(output, 0)
  end

  if status_text == nil then
    return new_http_response(output, 0)
  end

  local status_number = tonumber(status_text)

  if status_number == nil then
    return new_http_response(body, 0)
  end

  return new_http_response(body, status_number)
end

---@param url string
---@param data string?
---@param headers table<string, string>?
---@return GitLabDuoHttpResponse? response
---@return string? error_message
local function curl_post(url, data, headers)
  assert(type(url) == 'string')

  local curl_args = {
    'curl',
    '--location',
    '--max-time',
    tostring(HTTP_TIMEOUT_SECONDS),
    '--output',
    '-',
    '--silent',
    '--show-error',
    '--write-out',
    '\n%{http_code}',
    '--request',
    'POST',
    url,
  }

  if headers ~= nil then
    local header_keys = vim.tbl_keys(headers)

    table.sort(header_keys)

    for index = 1, #header_keys do
      local header_name = header_keys[index]
      local header_value = headers[header_name]

      assert(type(header_name) == 'string')
      assert(type(header_value) == 'string')

      curl_args[#curl_args + 1] = '--header'
      curl_args[#curl_args + 1] = header_name .. ': ' .. header_value
    end
  end

  if data ~= nil then
    curl_args[#curl_args + 1] = '--data'
    curl_args[#curl_args + 1] = data
  end

  local process = vim.system(curl_args, {
    text = true,
    timeout = HTTP_TIMEOUT_MS,
  })

  ---@type any
  local result_raw = process:wait()

  if type(result_raw) ~= 'table' then
    return nil, 'curl process returned no result'
  end

  ---@type any
  local result = result_raw

  local stdout = result.stdout

  if type(stdout) ~= 'string' then
    stdout = ''
  end

  local stderr = result.stderr

  if type(stderr) ~= 'string' then
    stderr = ''
  end

  local exit_code = result.code

  if type(exit_code) ~= 'number' then
    exit_code = -1
  end

  if exit_code ~= 0 and stdout == '' then
    return nil, 'curl request failed: ' .. stderr
  end

  return parse_curl_output(stdout), nil
end

---@param text string
---@return table? value
---@return string? error_message
local function decode_json_table(text)
  assert(type(text) == 'string')

  local decode_ok, value_or_error = pcall(vim.json.decode, text)

  if not decode_ok then
    return nil, 'failed to decode JSON: ' .. tostring(value_or_error)
  end

  if type(value_or_error) ~= 'table' then
    return nil, 'JSON payload must decode to an object'
  end

  return value_or_error, nil
end

---@param value table
---@return GitLabDuoToken? token
---@return string? error_message
local function validate_token(value)
  assert(type(value) == 'table')

  ---@type any
  local source = value

  local access_token = source.access_token
  local expires_in = source.expires_in
  local refresh_token = source.refresh_token
  local saved_at = source.saved_at
  local token_type = source.token_type

  if type(access_token) ~= 'string' or access_token == '' then
    return nil, 'token response is missing access_token'
  end

  if not is_integer(expires_in) or expires_in <= 0 then
    return nil, 'token response is missing a positive expires_in'
  end

  if refresh_token ~= nil and type(refresh_token) ~= 'string' then
    return nil, 'token response has invalid refresh_token'
  end

  if saved_at ~= nil and not is_integer(saved_at) then
    return nil, 'token response has invalid saved_at'
  end

  if token_type ~= nil and type(token_type) ~= 'string' then
    return nil, 'token response has invalid token_type'
  end

  ---@type GitLabDuoToken
  local token = {
    access_token = access_token,
    expires_in = expires_in,
    refresh_token = refresh_token,
    saved_at = saved_at,
    token_type = token_type,
  }

  return token, nil
end

---@param value table
---@return GitLabDuoDeviceAuthorization? authorization
---@return string? error_message
local function validate_device_authorization(value)
  assert(type(value) == 'table')

  ---@type any
  local source = value

  local device_code = source.device_code
  local expires_in = source.expires_in
  local interval = source.interval
  local user_code = source.user_code
  local verification_uri = source.verification_uri
  local verification_uri_complete = source.verification_uri_complete

  if type(device_code) ~= 'string' or device_code == '' then
    return nil, 'device authorization response is missing device_code'
  end

  if type(user_code) ~= 'string' or user_code == '' then
    return nil, 'device authorization response is missing user_code'
  end

  if type(verification_uri) ~= 'string' or verification_uri == '' then
    return nil, 'device authorization response is missing verification_uri'
  end

  if expires_in ~= nil and not is_integer(expires_in) then
    return nil, 'device authorization response has invalid expires_in'
  end

  if interval ~= nil then
    if not is_integer(interval) then
      return nil, 'device authorization response has invalid interval'
    end

    if interval <= 0 then
      return nil, 'device authorization response has invalid interval'
    end
  end

  if verification_uri_complete ~= nil and type(verification_uri_complete) ~= 'string' then
    return nil, 'device authorization response has invalid verification_uri_complete'
  end

  ---@type GitLabDuoDeviceAuthorization
  local authorization = {
    device_code = device_code,
    expires_in = expires_in,
    interval = interval,
    user_code = user_code,
    verification_uri = verification_uri,
    verification_uri_complete = verification_uri_complete,
  }

  return authorization, nil
end

---@param token GitLabDuoToken
---@return boolean? ok
---@return string? error_message
local function save_token(token)
  assert(type(token) == 'table')

  token.saved_at = os.time()

  local encode_ok, token_json_or_error = pcall(vim.json.encode, token)

  if not encode_ok then
    return nil, 'failed to encode OAuth token'
  end

  if type(token_json_or_error) ~= 'string' then
    return nil, 'OAuth token encoding returned non-string data'
  end

  local file, open_error = io.open(config.token_file, 'w')

  if file == nil then
    return nil, 'failed to open token file: ' .. tostring(open_error)
  end

  local write_ok, write_error = file:write(token_json_or_error)
  file:close()

  if not write_ok then
    return nil, 'failed to write token file: ' .. tostring(write_error)
  end

  return true, nil
end

---@return GitLabDuoToken? token
---@return string? error_message
local function load_token()
  if fn.filereadable(config.token_file) ~= 1 then
    return nil, 'token file does not exist'
  end

  local read_ok, blob_or_error = pcall(fn.readblob, config.token_file)

  if not read_ok then
    return nil, 'failed to read token file: ' .. tostring(blob_or_error)
  end

  if type(blob_or_error) ~= 'string' then
    return nil, 'token file did not produce string data'
  end

  local value, decode_error = decode_json_table(blob_or_error)

  if value == nil then
    return nil, decode_error
  end

  return validate_token(value)
end

---@param token GitLabDuoToken
---@return boolean
local function is_token_expired(token)
  assert(type(token) == 'table')

  if token.saved_at == nil then
    return true
  end

  local token_age_seconds = os.time() - token.saved_at
  local expiry_seconds = token.expires_in - TOKEN_EXPIRY_BUFFER_SECONDS

  return token_age_seconds >= expiry_seconds
end

---@param refresh_token string
---@return GitLabDuoToken? token
---@return string? error_message
local function refresh_access_token(refresh_token)
  assert(type(refresh_token) == 'string')
  assert(refresh_token ~= '')

  notify('Refreshing GitLab OAuth token...', vim.log.levels.INFO)

  local response, request_error = curl_post(
    config.gitlab_url .. '/oauth/token',
    encode_form({
      client_id = config.client_id,
      grant_type = 'refresh_token',
      refresh_token = refresh_token,
    }),
    {
      ['Content-Type'] = 'application/x-www-form-urlencoded',
    }
  )

  if response == nil then
    return nil, request_error
  end

  if response.status ~= 200 then
    return nil, 'token refresh failed with HTTP status ' .. tostring(response.status)
  end

  local value, decode_error = decode_json_table(response.body)

  if value == nil then
    return nil, decode_error
  end

  local token, validation_error = validate_token(value)

  if token == nil then
    return nil, validation_error
  end

  local save_ok, save_error = save_token(token)

  if not save_ok then
    return nil, save_error
  end

  notify('GitLab OAuth token refreshed successfully.', vim.log.levels.INFO)

  return token, nil
end

---@return string? access_token
---@return string status
local function get_valid_token()
  local token, load_error = load_token()

  if token == nil then
    if load_error ~= 'token file does not exist' then
      notify('GitLab Duo token could not be loaded.', vim.log.levels.WARN)
    end

    return nil, 'no_token'
  end

  if not is_token_expired(token) then
    return token.access_token, 'valid'
  end

  if token.refresh_token == nil or token.refresh_token == '' then
    return nil, 'expired'
  end

  local refreshed_token, refresh_error = refresh_access_token(token.refresh_token)

  if refreshed_token == nil then
    notify('GitLab Duo token refresh failed: ' .. (refresh_error or 'unknown error'), vim.log.levels.WARN)

    return nil, 'refresh_failed'
  end

  return refreshed_token.access_token, 'refreshed'
end

---@return GitLabDuoDeviceAuthorization? authorization
---@return string? error_message
local function device_authorization()
  local response, request_error = curl_post(
    config.gitlab_url .. '/oauth/authorize_device',
    encode_form({
      client_id = config.client_id,
      scope = config.scopes,
    }),
    {
      ['Content-Type'] = 'application/x-www-form-urlencoded',
    }
  )

  if response == nil then
    return nil, request_error
  end

  if response.status ~= 200 then
    return nil, 'device authorization failed with HTTP status ' .. tostring(response.status)
  end

  local value, decode_error = decode_json_table(response.body)

  if value == nil then
    return nil, decode_error
  end

  return validate_device_authorization(value)
end

---@param client vim.lsp.Client
---@param access_token string
local function notify_lsp_token(client, access_token)
  assert(type(access_token) == 'string')
  assert(access_token ~= '')

  client:notify(CONFIGURATION_METHOD, {
    settings = {
      baseUrl = config.gitlab_url,
      token = access_token,
    },
  })
end

---@param value table
---@return GitLabDuoOAuthError
local function read_oauth_error(value)
  assert(type(value) == 'table')

  ---@type any
  local source = value

  local error_code = source.error
  local error_description = source.error_description

  ---@type GitLabDuoOAuthError
  local oauth_error = {
    error = nil,
    error_description = nil,
  }

  if type(error_code) == 'string' then
    oauth_error.error = error_code
  end

  if type(error_description) == 'string' then
    oauth_error.error_description = error_description
  end

  return oauth_error
end

---@param device_code string
---@param interval_seconds number
---@param client vim.lsp.Client
local function poll_for_token(device_code, interval_seconds, client)
  assert(type(device_code) == 'string')
  assert(device_code ~= '')
  assert(is_integer(interval_seconds))
  assert(type(client) == 'table')

  local attempt_count = 0
  local poll_interval_seconds = math.max(interval_seconds, DEVICE_POLL_INTERVAL_SECONDS_MIN)

  ---@type fun()
  local poll

  local function schedule_next_poll()
    local delay_ms = to_integer(poll_interval_seconds * 1000)

    vim.defer_fn(poll, delay_ms)
  end

  poll = function()
    attempt_count = attempt_count + 1

    if attempt_count > DEVICE_POLL_ATTEMPT_COUNT_MAX then
      notify('GitLab device authorization timed out.', vim.log.levels.ERROR)
      return
    end

    local response, request_error = curl_post(
      config.gitlab_url .. '/oauth/token',
      encode_form({
        client_id = config.client_id,
        device_code = device_code,
        grant_type = 'urn:ietf:params:oauth:grant-type:device_code',
      }),
      {
        ['Content-Type'] = 'application/x-www-form-urlencoded',
      }
    )

    if response == nil then
      notify('GitLab token polling failed: ' .. (request_error or 'unknown error'), vim.log.levels.ERROR)
      return
    end

    local value, decode_error = decode_json_table(response.body)

    if value == nil then
      notify('GitLab token response could not be decoded: ' .. (decode_error or 'unknown error'), vim.log.levels.ERROR)
      return
    end

    if response.status == 200 then
      local token, validation_error = validate_token(value)

      if token == nil then
        notify('GitLab token response is invalid: ' .. (validation_error or 'unknown error'), vim.log.levels.ERROR)
        return
      end

      local save_ok, save_error = save_token(token)

      if not save_ok then
        notify('GitLab token could not be saved: ' .. (save_error or 'unknown error'), vim.log.levels.ERROR)
        return
      end

      notify('GitLab Duo authentication successful.', vim.log.levels.INFO)

      vim.schedule(function()
        notify_lsp_token(client, token.access_token)
      end)

      return
    end

    local oauth_error = read_oauth_error(value)

    if oauth_error.error == 'authorization_pending' then
      schedule_next_poll()
      return
    end

    if oauth_error.error == 'slow_down' then
      poll_interval_seconds = poll_interval_seconds + 5
      schedule_next_poll()
      return
    end

    if oauth_error.error == 'access_denied' then
      notify('GitLab device authorization was denied.', vim.log.levels.ERROR)
      return
    end

    if oauth_error.error == 'expired_token' then
      notify('GitLab device code expired. Run :LspGitLabDuoSignIn again.', vim.log.levels.ERROR)
      return
    end

    notify('GitLab OAuth error: ' .. (oauth_error.error or 'unknown error'), vim.log.levels.ERROR)
  end

  poll()
end

---@param client vim.lsp.Client
local function sign_in(client)
  notify('Starting GitLab device authorization...', vim.log.levels.INFO)

  local authorization, authorization_error = device_authorization()

  if authorization == nil then
    notify('GitLab device authorization failed: ' .. (authorization_error or 'unknown error'), vim.log.levels.ERROR)
    return
  end

  local authorization_url = authorization.verification_uri_complete

  if authorization_url == nil or authorization_url == '' then
    authorization_url = authorization.verification_uri .. '?user_code=' .. form_encode(authorization.user_code)
  end

  vim.ui.open(authorization_url)

  local interval_seconds = authorization.interval

  if interval_seconds == nil then
    interval_seconds = DEVICE_POLL_INTERVAL_SECONDS_DEFAULT
  end

  if interval_seconds < DEVICE_POLL_INTERVAL_SECONDS_MIN then
    interval_seconds = DEVICE_POLL_INTERVAL_SECONDS_MIN
  end

  poll_for_token(authorization.device_code, interval_seconds, client)
end

---@param client vim.lsp.Client
local function sign_out(client)
  local remove_ok, remove_error = os.remove(config.token_file)

  if not remove_ok then
    notify('Failed to remove GitLab Duo token file: ' .. tostring(remove_error), vim.log.levels.ERROR)
    return
  end

  client:notify(CONFIGURATION_METHOD, {
    settings = {
      baseUrl = config.gitlab_url,
      token = '',
    },
  })

  notify('Signed out. GitLab Duo token removed.', vim.log.levels.INFO)
end

local function show_status()
  local token, load_error = load_token()

  if token == nil then
    if load_error == 'token file does not exist' then
      notify('Not signed in. Run :LspGitLabDuoSignIn to authenticate.', vim.log.levels.INFO)
      return
    end

    notify('GitLab Duo token could not be loaded: ' .. (load_error or 'unknown error'), vim.log.levels.ERROR)
    return
  end

  local status_lines = {
    'GitLab Duo Status:',
    '',
    'Instance: ' .. config.gitlab_url,
    'Signed in: Yes',
    'Has refresh token: ' .. (token.refresh_token and 'Yes' or 'No'),
  }

  if token.saved_at == nil then
    status_lines[#status_lines + 1] = 'Token expiration: Unknown'
  else
    local seconds_remaining = token.expires_in - (os.time() - token.saved_at)

    if seconds_remaining <= 0 then
      status_lines[#status_lines + 1] = 'Token status: EXPIRED'
    else
      local hours = math.floor(seconds_remaining / 3600)
      local minutes = math.floor((seconds_remaining % 3600) / 60)

      status_lines[#status_lines + 1] = string.format('Token expires in: %dh %dm', hours, minutes)
    end
  end

  notify(table.concat(status_lines, '\n'), vim.log.levels.INFO)
end

---@param client vim.lsp.Client
---@param result any
local function handle_token_check(client, result)
  if type(result) ~= 'table' then
    return
  end

  ---@type any
  local result_table = result

  local reason = result_table.reason
  local message = result_table.message

  if type(reason) ~= 'string' or reason == '' then
    return
  end

  if type(message) ~= 'string' then
    message = ''
  end

  notify(string.format('GitLab Duo: %s - %s', reason, message), vim.log.levels.ERROR)

  local token = load_token()

  if token == nil then
    notify('Run :LspGitLabDuoSignIn to authenticate.', vim.log.levels.WARN)
    return
  end

  if token.refresh_token == nil or token.refresh_token == '' then
    notify('Run :LspGitLabDuoSignIn to authenticate.', vim.log.levels.WARN)
    return
  end

  ---@type string
  local refresh_token = token.refresh_token

  vim.schedule(function()
    local refreshed_token, refresh_error = refresh_access_token(refresh_token)

    if refreshed_token == nil then
      notify('GitLab Duo refresh failed: ' .. (refresh_error or 'unknown error'), vim.log.levels.WARN)
      notify('Run :LspGitLabDuoSignIn to re-authenticate.', vim.log.levels.WARN)
      return
    end

    notify_lsp_token(client, refreshed_token.access_token)
  end)
end

---@param result any
local function handle_feature_state_change(result)
  if type(result) ~= 'table' then
    return
  end

  ---@type any
  local result_table = result

  local state = result_table.state
  local checks = result_table.checks

  if state ~= 'disabled' then
    return
  end

  if type(checks) ~= 'table' then
    return
  end

  for index = 1, #checks do
    local check_raw = checks[index]

    if type(check_raw) == 'table' then
      ---@type any
      local check = check_raw

      local message = check.message

      if type(message) ~= 'string' or message == '' then
        message = check.id
      end

      if type(message) == 'string' and message ~= '' then
        notify('GitLab Duo: ' .. message, vim.log.levels.WARN)
      end
    end
  end
end

---@param client vim.lsp.Client
local function configure_handlers(client)
  client.handlers['$/gitlab/token/check'] = function(_, result)
    handle_token_check(client, result)
  end

  client.handlers['$/gitlab/featureStateChange'] = function(_, result)
    handle_feature_state_change(result)
  end
end

---@param client vim.lsp.Client
local function configure_initial_token(client)
  local access_token, status = get_valid_token()

  if access_token == nil then
    notify('GitLab Duo is not authenticated. Run :LspGitLabDuoSignIn.', vim.log.levels.WARN)
    return
  end

  notify_lsp_token(client, access_token)

  if status == 'refreshed' then
    notify('GitLab Duo token refreshed automatically.', vim.log.levels.INFO)
  end
end

---@param client vim.lsp.Client
---@param bufnr integer
local function create_buffer_commands(client, bufnr)
  api.nvim_buf_create_user_command(bufnr, 'LspGitLabDuoSignIn', function()
    sign_in(client)
  end, {
    desc = 'Sign in to GitLab Duo with OAuth device authorization',
    force = true,
  })

  api.nvim_buf_create_user_command(bufnr, 'LspGitLabDuoSignOut', function()
    sign_out(client)
  end, {
    desc = 'Sign out from GitLab Duo',
    force = true,
  })

  api.nvim_buf_create_user_command(bufnr, 'LspGitLabDuoStatus', function()
    show_status()
  end, {
    desc = 'Show GitLab Duo authentication status',
    force = true,
  })
end

---@type vim.lsp.Config
return {
  cmd = {
    'npx',
    '--registry=https://gitlab.com/api/v4/packages/npm/',
    '@gitlab-org/gitlab-lsp',
    '--stdio',
  },
  filetypes = {
    'c',
    'cpp',
    'cs',
    'css',
    'go',
    'html',
    'java',
    'javascript',
    'javascriptreact',
    'json',
    'kotlin',
    'lua',
    'php',
    'python',
    'ruby',
    'rust',
    'scala',
    'scss',
    'svelte',
    'swift',
    'typescript',
    'typescriptreact',
    'vue',
    'yaml',
  },
  init_options = {
    editorInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
    editorPluginInfo = {
      name = 'Neovim LSP Client',
      version = tostring(vim.version()),
    },
    extension = {
      name = 'Neovim LSP Client',
      version = tostring(vim.version()),
    },
    ide = {
      name = 'Neovim',
      vendor = 'Neovim',
      version = tostring(vim.version()),
    },
  },
  on_attach = function(client, bufnr)
    create_buffer_commands(client, bufnr)
  end,
  on_init = function(client)
    configure_handlers(client)
    configure_initial_token(client)
  end,
  root_markers = {
    '.git',
  },
  settings = {
    baseUrl = config.gitlab_url,
    codeCompletion = {
      enableSecretRedaction = true,
    },
    featureFlags = {
      streamCodeGenerations = false,
    },
    logLevel = 'info',
    telemetry = {
      enabled = false,
    },
  },
}
