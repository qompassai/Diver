-- lua/utils/sf/package.lua
-- Wraps: @salesforce/plugin-packaging
-- Topics: package create | package version create | package install | package list
local util = require('utils.sf.util')
local M = {}

-- :SfPackageCreate
function M.create()
  if not util.ensure_sf() or not util.ensure_project() then return end
  local name = vim.fn.input('Package name> ')
  if name == '' then return end
  local ptype = vim.fn.input('Type (Unlocked/Managed, default Unlocked)> ')
  ptype = ptype ~= '' and ptype or 'Unlocked'
  local path  = vim.fn.input('Package root path (default force-app)> ')
  path  = path  ~= '' and path  or 'force-app'
  util.open_term_cmd(
    'sf package create --name ' .. util.shellescape(name)
    .. ' --package-type ' .. util.shellescape(ptype)
    .. ' --path '         .. util.shellescape(path),
    20)
end

-- :SfPackageVersionCreate
function M.version_create()
  if not util.ensure_sf() or not util.ensure_project() then return end
  local pkg = vim.fn.input('Package name or ID> ')
  if pkg == '' then return end
  local wait = vim.fn.input('Wait minutes (default 20)> ')
  wait = wait ~= '' and wait or '20'
  util.open_term_cmd(
    'sf package version create --package ' .. util.shellescape(pkg)
    .. ' --installation-key-bypass --wait ' .. util.shellescape(wait),
    tonumber(wait) + 5)
end

-- :SfPackageVersionCreateStatus  -- poll an in-progress version create job
function M.version_create_status()
  if not util.ensure_sf() then return end
  local job_id = vim.fn.input('Package version create request ID> ')
  if job_id == '' then return end
  util.open_term_cmd(
    'sf package version create report --package-create-request-id '
    .. util.shellescape(job_id), 20)
end

-- :SfPackageInstall
function M.install()
  if not util.ensure_sf() or not util.ensure_org() then return end
  local version_id = vim.fn.input('Package version ID (04t...)> ')
  if version_id == '' then return end
  util.open_term_cmd(
    'sf package install --package ' .. util.shellescape(version_id)
    .. ' --wait 10 --no-prompt', 20)
end

-- :SfPackageList
function M.list()
  if not util.ensure_sf() then return end
  util.open_term_cmd('sf package list', 20)
end

-- :SfPackageVersionList
function M.version_list()
  if not util.ensure_sf() then return end
  local pkg = vim.fn.input('Package name or ID (blank = all)> ')
  local cmd = 'sf package version list --verbose'
  if pkg ~= '' then
    cmd = cmd .. ' --package ' .. util.shellescape(pkg)
  end
  util.open_term_cmd(cmd, 20)
end

-- :SfPackageUninstall
function M.uninstall()
  if not util.ensure_sf() or not util.ensure_org() then return end
  local pkg_id = vim.fn.input('Package ID (0Ho...)> ')
  if pkg_id == '' then return end
  util.open_term_cmd(
    'sf package uninstall --package ' .. util.shellescape(pkg_id) .. ' --wait 10', 20)
end

return M
