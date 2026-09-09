-- /qompassai/Diver/lua/utils/dev/sf/org.lua
-- Qompass AI Diver Salesforce Org Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local core = require('utils.dev.sf.core')
local fn = vim.fn
local M = {}
---@param argv string[]
---@param flag string
---@param value? string
local function append_value(argv, flag, value)
  if type(value) == 'string' and value ~= '' then
    argv[#argv + 1] = flag
    argv[#argv + 1] = value
  end
end

function M.current()
  if core.ensure() then
    core.open_term_cmd({
      'sf',
      'config',
      'get',
      'target-org',
    }, 12)
  end
end

---@param opts? SfCommandArgs
function M.display(opts)
  if not core.ensure() then
    return
  end
  local argv = {
    'sf',
    'org',
    'display',
  }
  append_value(argv, '--target-org', core.get_arg(opts))
  core.open_term_cmd(argv, 20)
end

function M.list()
  if core.ensure() then
    core.open_term_cmd({ 'sf', 'org', 'list' }, 20)
  end
end

---@param opts? SfCommandArgs
function M.login_web(opts)
  if not core.ensure() then
    return
  end
  local alias = core.get_arg(opts) or fn.input('Org alias (optional)> ')
  local argv = { 'sf', 'org', 'login', 'web' }
  append_value(argv, '--alias', alias)
  core.open_term_cmd(argv, 20)
end

M.auth_web_login = M.login_web

---@param opts? SfCommandArgs
function M.logout(opts)
  if not core.ensure() then
    return
  end
  local org = core.get_arg(opts) or fn.input('Org alias or username to logout> ')
  if type(org) ~= 'string' or org == '' then
    return
  end
  core.open_term_cmd({
    'sf',
    'org',
    'logout',
    '--target-org',
    org,
    '--no-prompt',
  }, 20)
end

M.auth_logout = M.logout

---@param opts? SfCommandArgs
function M.open(opts)
  if not core.ensure() then
    return
  end
  local argv = {
    'sf',
    'org',
    'open',
  }
  append_value(argv, '--target-org', core.get_arg(opts))
  core.open_term_cmd(argv, 12)
end

---@param opts? SfCommandArgs
function M.set_default(opts)
  if not core.ensure() then
    return
  end
  local org = core.input_or_arg(opts, 'Target org alias or username> ')
  if not org then
    return
  end
  core.open_term_cmd({
    'sf',
    'config',
    'set',
    'target-org=' .. org,
  }, 12)
end

function M.auth_jwt_grant()
  if not core.ensure() then
    return
  end
  local username = core.input_required('Username> ')
  if not username then
    return
  end
  local client_id = core.input_required('Connected App Client ID> ')
  if not client_id then
    return
  end
  local key_file = core.input_required('Private key file> ', 'file')
  if not key_file then
    return
  end
  local alias = fn.input('Org alias (optional)> ')
  local argv = {
    'sf',
    'org',
    'login',
    'jwt',
    '--username',
    username,
    '--client-id',
    client_id,
    '--jwt-key-file',
    key_file,
  }
  append_value(argv, '--alias', alias)
  core.open_term_cmd(argv, 20)
end

function M.auth_list()
  if core.ensure() then
    core.open_term_cmd({
      'sf',
      'org',
      'list',
      'auth',
    }, 20)
  end
end

function M.auth_logout_all()
  if not core.ensure() then
    return
  end
  if fn.input('Logout ALL orgs? Type yes to continue> ') ~= 'yes' then
    core.notify('Logout cancelled', vim.log.levels.INFO)
    return
  end
  core.open_term_cmd({
    'sf',
    'org',
    'logout',
    '--all',
    '--no-prompt',
  }, 20)
end
function M.auth_accesstoken_store()
  if not core.ensure() then
    return
  end
  local instance_url = core.input_required('Instance URL> ')
  if not instance_url then
    return
  end
  local alias = fn.input('Org alias (optional)> ')
  local argv = {
    'sf',
    'org',
    'login',
    'access-token',
    '--instance-url',
    instance_url,
  }
  append_value(argv, '--alias', alias)
  core.open_term_cmd(argv, 20)
end

function M.community_create()
  if not core.ensure({ org = true }) then
    return
  end
  local name = core.input_required('Experience Cloud site name> ')
  if not name then
    return
  end
  local template = core.input_required('Template name> ')
  if not template then
    return
  end
  local url_path = core.input_required('URL path prefix> ')
  if not url_path then
    return
  end
  core.open_term_cmd({
    'sf',
    'community',
    'create',
    '--name',
    name,
    '--template-name',
    template,
    '--url-path-prefix',
    url_path,
  }, 20)
end

function M.community_list()
  if core.ensure({ org = true }) then
    core.open_term_cmd({
      'sf',
      'community',
      'list',
      'template',
    }, 20)
  end
end

M.community_list_templates = M.community_list

function M.community_publish()
  if not core.ensure({ org = true }) then
    return
  end
  local name = core.input_required('Experience Cloud site name> ')
  if not name then
    return
  end
  core.open_term_cmd({ 'sf', 'community', 'publish', '--name', name }, 20)
end

M.commands = {
  {
    name = 'SfAuthAccesstokenStore',
    fn = M.auth_accesstoken_store,
    opts = {
      desc = 'Authenticate using a Salesforce access token',
      nargs = 0,
    },
  },
  {
    name = 'SfAuthJwtGrant',
    fn = M.auth_jwt_grant,
    opts = {
      desc = 'Authenticate with a JWT grant',
      nargs = 0,
    },
  },
  {
    name = 'SfAuthList',
    fn = M.auth_list,
    opts = {
      desc = 'List Salesforce authorization records',
      nargs = 0,
    },
  },
  {
    name = 'SfAuthLogout',
    fn = M.auth_logout,
    opts = {
      desc = 'Log out from a Salesforce org',
      nargs = '?',
    },
  },
  {
    name = 'SfAuthLogoutAll',
    fn = M.auth_logout_all,
    opts = {
      desc = 'Log out from all Salesforce authorization records',
      nargs = 0,
    },
  },
  {
    name = 'SfAuthWebLogin',
    fn = M.auth_web_login,
    opts = {
      desc = 'Authenticate with Salesforce web login',
      nargs = '?',
    },
  },
  {
    name = 'SfCommunityCreate',
    fn = M.community_create,
    opts = { desc = 'Create an Experience Cloud site', nargs = 0 },
  },
  {
    name = 'SfCommunityList',
    fn = M.community_list,
    opts = {
      desc = 'List Experience Cloud site templates',
      nargs = 0,
    },
  },
  {
    name = 'SfCommunityPublish',
    fn = M.community_publish,
    opts = { desc = 'Publish an Experience Cloud site', nargs = 0 },
  },
  {
    name = 'SfOrgCurrent',
    fn = M.current,
    opts = {
      desc = 'Show the current default org',
      nargs = 0,
    },
  },
  {
    name = 'SfOrgDisplay',
    fn = M.display,
    opts = {
      desc = 'Display org details',
      nargs = '?',
    },
  },
  {
    name = 'SfOrgList',
    fn = M.list,
    opts = {
      desc = 'List Salesforce orgs',
      nargs = 0,
    },
  },
  {
    name = 'SfOrgLoginWeb',
    fn = M.login_web,
    opts = {
      desc = 'Log in to an org via web',
      nargs = '?',
    },
  },
  {
    name = 'SfOrgLogout',
    fn = M.logout,
    opts = {
      desc = 'Log out from an org',
      nargs = '?',
    },
  },
  {
    name = 'SfOrgOpen',
    fn = M.open,
    opts = {
      desc = 'Open an org in a browser',
      nargs = '?',
    },
  },
  {
    name = 'SfOrgSetDefault',
    fn = M.set_default,
    opts = {
      desc = 'Set the default target org',
      nargs = '?',
    },
  },
}

return M