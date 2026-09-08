g.lua
-- /qompassai/Diver/lua/utils/dev/sf/org.lua
local core = require('utils.dev.sf.core')

local M = {}

function M.current()
  if not core.ensure_sf() then
    return
  end
  core.open_term_cmd('sf config get target-org', 12)
end

---@param opts? table
function M.display(opts)
  if not core.ensure_sf() then
    return
  end
  local org = core.get_arg(opts)
  local cmd = 'sf org display'
  if org and org ~= '' then
    cmd = cmd .. ' --target-org ' .. core.shellescape(org)
  end
  core.open_term_cmd(cmd, 20)
end

function M.list()
  if core.ensure_sf() then
    core.open_term_cmd('sf org list', 20)
  end
end

---@param opts? table
function M.login_web(opts)
  if not core.ensure_sf() then
    return
  end
  local alias = core.get_arg(opts) or vim.fn.input('Org alias (optional)> ')
  local cmd = 'sf org login web'
  if alias and alias ~= '' then
    cmd = cmd .. ' --alias ' .. core.shellescape(alias)
  end
  core.open_term_cmd(cmd, 20)
end

---@param opts? table
function M.logout(opts)
  if not core.ensure_sf() then
    return
  end
  local org = core.get_arg(opts) or vim.fn.input('Org alias or username to logout> ')
  if org == '' then
    return
  end
  core.open_term_cmd('sf org logout --target-org ' .. core.shellescape(org) .. ' --no-prompt', 20)
end

---@param opts? table
function M.open(opts)
  if not core.ensure_sf() then
    return
  end
  local org = core.get_arg(opts)
  local cmd = 'sf org open'
  if org and org ~= '' then
    cmd = cmd .. ' --target-org ' .. core.shellescape(org)
  end
  core.open_term_cmd(cmd, 12)
end

---@param opts? table
function M.set_default(opts)
  if not core.ensure_sf() then
    return
  end
  local org = core.input_or_arg(opts, 'Target org alias or username> ')
  if not org then
    return
  end
  core.open_term_cmd('sf config set target-org=' .. core.shellescape(org), 12)
end

---@param opts? table
function M.auth_web_login(opts)
  if not core.ensure_sf() then
    return
  end
  local alias = core.get_arg(opts) or vim.fn.input('Org alias (optional)> ')
  local cmd = 'sf auth web login'
  if alias and alias ~= '' then
    cmd = cmd .. ' --alias ' .. core.shellescape(alias)
  end
  core.open_term_cmd(cmd, 20)
end

function M.auth_jwt_grant()
  if not core.ensure_sf() then
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
  local alias = vim.fn.input('Org alias (optional)> ')
  local cmd = 'sf auth jwt grant --username '
    .. core.shellescape(username)
    .. ' --client-id '
    .. core.shellescape(client_id)
    .. ' --jwt-key-file '
    .. core.shellescape(key_file)
  if alias ~= '' then
    cmd = cmd .. ' --alias ' .. core.shellescape(alias)
  end
  core.open_term_cmd(cmd, 20)
end

function M.auth_list()
  if core.ensure_sf() then
    core.open_term_cmd('sf auth list', 20)
  end
end

---@param opts? table
function M.auth_logout(opts)
  if not core.ensure_sf() then
    return
  end
  local org = core.get_arg(opts) or vim.fn.input('Org alias or username to logout> ')
  if org == '' then
    return
  end
  core.open_term_cmd('sf auth logout --target-org ' .. core.shellescape(org) .. ' --no-prompt', 20)
end

function M.auth_logout_all()
  if not core.ensure_sf() then
    return
  end
  if vim.fn.input('Logout ALL orgs? (yes/no)> ') ~= 'yes' then
    core.notify('Logout cancelled', vim.log.levels.INFO)
    return
  end
  core.open_term_cmd('sf auth logout --all --no-prompt', 20)
end

function M.auth_accesstoken_store()
  if not core.ensure_sf() then
    return
  end
  local instance = core.input_required('Instance URL> ')
  if not instance then
    return
  end
  local alias = vim.fn.input('Org alias (optional)> ')
  local cmd = 'sf auth accesstoken store --instance-url ' .. core.shellescape(instance)
  if alias ~= '' then
    cmd = cmd .. ' --alias ' .. core.shellescape(alias)
  end
  core.open_term_cmd(cmd, 20)
end

function M.community_create()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local name = core.input_required('Community name> ')
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
  core.open_term_cmd(
    'sf community create --name '
      .. core.shellescape(name)
      .. ' --template-name '
      .. core.shellescape(template)
      .. ' --url-path-prefix '
      .. core.shellescape(url_path),
    20
  )
end

function M.community_list()
  if core.ensure_sf() and core.ensure_org() then
    core.open_term_cmd('sf community list', 20)
  end
end

function M.community_publish()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local name = core.input_required('Community name> ')
  if not name then
    return
  end
  core.open_term_cmd('sf community publish --name ' .. core.shellescape(name), 20)
end

M.commands = {
  { name = 'SfOrgCurrent', fn = M.current, opts = { desc = 'Show the current default org', nargs = 0 } },
  { name = 'SfOrgDisplay', fn = M.display, opts = { desc = 'Display org details', nargs = '?' } },
  { name = 'SfOrgList', fn = M.list, opts = { desc = 'List Salesforce orgs', nargs = 0 } },
  { name = 'SfOrgLoginWeb', fn = M.login_web, opts = { desc = 'Log in to an org via web', nargs = '?' } },
  { name = 'SfOrgLogout', fn = M.logout, opts = { desc = 'Log out from an org', nargs = '?' } },
  { name = 'SfOrgOpen', fn = M.open, opts = { desc = 'Open an org in a browser', nargs = '?' } },
  { name = 'SfOrgSetDefault', fn = M.set_default, opts = { desc = 'Set the default target org', nargs = '?' } },
  { name = 'SfAuthAccesstokenStore', fn = M.auth_accesstoken_store, opts = { desc = 'Store a Salesforce access token', nargs = 0 } },
  { name = 'SfAuthJwtGrant', fn = M.auth_jwt_grant, opts = { desc = 'Authenticate with a JWT grant', nargs = 0 } },
  { name = 'SfAuthList', fn = M.auth_list, opts = { desc = 'List Salesforce authentication records', nargs = 0 } },
  { name = 'SfAuthLogout', fn = M.auth_logout, opts = { desc = 'Log out using Salesforce auth', nargs = '?' } },
  { name = 'SfAuthLogoutAll', fn = M.auth_logout_all, opts = { desc = 'Log out from all Salesforce auth records', nargs = 0 } },
  { name = 'SfAuthWebLogin', fn = M.auth_web_login, opts = { desc = 'Authenticate with Salesforce web login', nargs = '?' } },
  { name = 'SfCommunityCreate', fn = M.community_create, opts = { desc = 'Create a Salesforce community', nargs = 0 } },
  { name = 'SfCommunityList', fn = M.community_list, opts = { desc = 'List Salesforce communities', nargs = 0 } },
  { name = 'SfCommunityPublish', fn = M.community_publish, opts = { desc = 'Publish a Salesforce community', nargs = 0 } },
}

return M