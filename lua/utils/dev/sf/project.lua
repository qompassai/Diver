-- /qompassai/Diver/lua/utils/dev/sf/project.lua
-- Qompass AI Diver Salesforce Project Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local core = require('utils.dev.sf.core')
local fn = vim.fn
local M = {}
---@return string?
local function current_file()
  local path = core.current_file()
  if path == '' then
    core.notify('Current buffer is not backed by a file', vim.log.levels.WARN)
    return nil
  end
  return path
end

---@return boolean
local function ready()
  return core.ensure({ project = true })
end

function M.deploy_current()
  if not ready() then
    return
  end
  local path = current_file()
  if path then
    core.open_term_cmd({
      'sf',
      'project',
      'deploy',
      'start',
      '--source-dir',
      path,
    }, 20)
  end
end

---@param opts? SfCommandArgs
function M.deploy_file(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or fn.input('File to deploy> ', fn.expand('%:p'), 'file')
  if type(path) == 'string' and path ~= '' then
    core.open_term_cmd({
      'sf',
      'project',
      'deploy',
      'start',
      '--source-dir',
      path,
    }, 20)
  end
end
---@param opts? SfCommandArgs
function M.deploy_manifest(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or fn.input('Manifest file> ', 'package.xml', 'file')
  if type(path) == 'string' and path ~= '' then
    core.open_term_cmd({
      'sf',
      'project',
      'deploy',
      'start',
      '--manifest',
      path,
    }, 20)
  end
end

---@param opts? SfCommandArgs
function M.deploy_project(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or 'force-app'
  core.open_term_cmd({
    'sf',
    'project',
    'deploy',
    'start',
    '--source-dir',
    path,
  }, 20)
end

---@param opts? SfCommandArgs
function M.deploy_validate(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or 'force-app'
  core.open_term_cmd({
    'sf',
    'project',
    'deploy',
    'validate',
    '--source-dir',
    path,
  }, 20)
end

function M.retrieve_current()
  if not ready() then
    return
  end
  local path = current_file()
  if path then
    core.open_term_cmd({
      'sf',
      'project',
      'retrieve',
      'start',
      '--source-dir',
      path,
    }, 20)
  end
end

---@param opts? SfCommandArgs
function M.retrieve_file(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or fn.input('File to retrieve> ', fn.expand('%:p'), 'file')
  if type(path) == 'string' and path ~= '' then
    core.open_term_cmd({
      'sf',
      'project',
      'retrieve',
      'start',
      '--source-dir',
      path,
    }, 20)
  end
end

---@param opts? SfCommandArgs
function M.retrieve_manifest(opts)
  if not ready() then
    return
  end
  local path = core.get_arg(opts) or fn.input('Manifest file> ', 'package.xml', 'file')
  if type(path) == 'string' and path ~= '' then
    core.open_term_cmd({
      'sf',
      'project',
      'retrieve',
      'start',
      '--manifest',
      path,
    }, 20)
  end
end

M.commands = {
  {
    name = 'SfDeployCurrent',
    fn = M.deploy_current,
    opts = {
      desc = 'Deploy the current Salesforce source file',
      nargs = 0,
    },
  },
  {
    name = 'SfDeployFile',
    fn = M.deploy_file,
    opts = {
      complete = 'file',
      desc = 'Deploy a Salesforce source file',
      nargs = '?',
    },
  },
  {
    name = 'SfDeployManifest',
    fn = M.deploy_manifest,
    opts = {
      complete = 'file',
      desc = 'Deploy from a package manifest',
      nargs = '?',
    },
  },
  {
    name = 'SfDeployProject',
    fn = M.deploy_project,
    opts = {
      complete = 'dir',
      desc = 'Deploy a Salesforce source directory',
      nargs = '?',
    },
  },
  {
    name = 'SfDeployValidate',
    fn = M.deploy_validate,
    opts = {
      complete = 'dir',
      desc = 'Validate a Salesforce deployment',
      nargs = '?',
    },
  },
  {
    name = 'SfRetrieveCurrent',
    fn = M.retrieve_current,
    opts = {
      desc = 'Retrieve the current Salesforce source file',
      nargs = 0,
    },
  },
  {
    name = 'SfRetrieveFile',
    fn = M.retrieve_file,
    opts = {
      complete = 'file',
      desc = 'Retrieve a Salesforce source file',
      nargs = '?',
    },
  },
  {
    name = 'SfRetrieveManifest',
    fn = M.retrieve_manifest,
    opts = {
      complete = 'file',
      desc = 'Retrieve from a package manifest',
      nargs = '?',
    },
  },
}

return M