-- lua/utils/sf/community.lua
-- Wraps: @salesforce/plugin-community
-- Topics: community create | community list | community publish
local util = require('utils.sf.util')
local M = {}

-- :SfCommunityCreate
function M.create()
  if not util.ensure_sf() or not util.ensure_org() then return end
  local name     = vim.fn.input('Community name> ')
  if name == '' then return end
  local template = vim.fn.input('Template (e.g. VF Template)> ')
  if template == '' then return end
  local url_path = vim.fn.input('URL path prefix (e.g. /mysite)> ')
  if url_path == '' then return end
  util.open_term_cmd(
    'sf community create --name ' .. util.shellescape(name)
    .. ' --template-name ' .. util.shellescape(template)
    .. ' --url-path-prefix ' .. util.shellescape(url_path), 20)
end

-- :SfCommunityList
function M.list()
  if not util.ensure_sf() or not util.ensure_org() then return end
  util.open_term_cmd('sf community list', 20)
end

-- :SfCommunityPublish
function M.publish()
  if not util.ensure_sf() or not util.ensure_org() then return end
  local name = vim.fn.input('Community name> ')
  if name == '' then return end
  util.open_term_cmd(
    'sf community publish --name ' .. util.shellescape(name), 20)
end

return M
