 $ cat project.lua
-- /qompassai/Diver/lua/utils/dev/sf/project.lua
local core = require('utils.dev.sf.core')

local M = {}

local function current_file()
  local file = core.current_file()
  if file == '' then
    core.notify('Current buffer is not backed by a file', vim.log.levels.WARN)
    return nil
  end
  return file
end

function M.deploy_current()
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = current_file()
  if file then
    core.open_term_cmd('sf project deploy start --source-file ' .. core.shellescape(file), 20)
  end
end

---@param opts? table
function M.deploy_file(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = core.get_arg(opts) or vim.fn.input('File to deploy> ', vim.fn.expand('%:p'), 'file')
  if file ~= '' then
    core.open_term_cmd('sf project deploy start --source-file ' .. core.shellescape(file), 20)
  end
end

---@param opts? table
function M.deploy_manifest(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = core.get_arg(opts) or vim.fn.input('Manifest file> ', 'package.xml', 'file')
  if file ~= '' then
    core.open_term_cmd('sf project deploy start --manifest ' .. core.shellescape(file), 20)
  end
end

---@param opts? table
function M.deploy_project(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local path = core.get_arg(opts) or 'force-app'
  core.open_term_cmd('sf project deploy start --source-dir ' .. core.shellescape(path), 20)
end

---@param opts? table
function M.deploy_validate(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local path = core.get_arg(opts) or 'force-app'
  core.open_term_cmd('sf project deploy validate --source-dir ' .. core.shellescape(path), 20)
end

function M.retrieve_current()
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = current_file()
  if file then
    core.open_term_cmd('sf project retrieve start --source-file ' .. core.shellescape(file), 20)
  end
end

---@param opts? table
function M.retrieve_file(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = core.get_arg(opts) or vim.fn.input('File to retrieve> ', vim.fn.expand('%:p'), 'file')
  if file ~= '' then
    core.open_term_cmd('sf project retrieve start --source-file ' .. core.shellescape(file), 20)
  end
end

---@param opts? table
function M.retrieve_manifest(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local file = core.get_arg(opts) or vim.fn.input('Manifest file> ', 'package.xml', 'file')
  if file ~= '' then
    core.open_term_cmd('sf project retrieve start --manifest ' .. core.shellescape(file), 20)
  end
end

M.commands = {
  { name = 'SfDeployCurrent', fn = M.deploy_current, opts = { desc = 'Deploy the current Salesforce source file', nargs = 0 } },
  { name = 'SfDeployFile', fn = M.deploy_file, opts = { desc = 'Deploy a Salesforce source file', nargs = '?' } },
  { name = 'SfDeployManifest', fn = M.deploy_manifest, opts = { desc = 'Deploy from a package manifest', nargs = '?' } },
  { name = 'SfDeployProject', fn = M.deploy_project, opts = { desc = 'Deploy a Salesforce source directory', nargs = '?' } },
  { name = 'SfDeployValidate', fn = M.deploy_validate, opts = { desc = 'Validate a Salesforce deployment', nargs = '?' } },
  { name = 'SfRetrieveCurrent', fn = M.retrieve_current, opts = { desc = 'Retrieve the current Salesforce source file', nargs = 0 } },
  { name = 'SfRetrieveFile', fn = M.retrieve_file, opts = { desc = 'Retrieve a Salesforce source file', nargs = '?' } },
  { name = 'SfRetrieveManifest', fn = M.retrieve_manifest, opts = { desc = 'Retrieve from a package manifest', nargs = '?' } },
}

return M