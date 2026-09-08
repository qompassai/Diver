-- /qompassai/Diver/lua/utils/docs/journal.lua
-- Qompass AI Diver Journal Profile Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

M.profiles = {
  jgme = {
    name = 'Journal of Graduate Medical Education',
    article_types = {
      'Original Research',
      'Perspectives',
      'Educational Innovation',
      'Brief Report',
      'Review',
      'Letter to the Editor',
    },
    review = {
      fields = {
        'Reviewer Recommendation',
        'Overall Manuscript Rating',
        'Topic importance',
        'Conclusions supported',
        'Novelty',
        'Additional statistical review',
      },
    },
  },
  generic = {
    name = 'Journal',
    article_types = {},
    review = {
      fields = {
        'Recommendation',
        'Overall rating',
        'Importance',
        'Validity',
        'Novelty',
      },
    },
  },
}

---@param name string
---@return table
function M.get(name)
  return M.profiles[name:lower()] or M.profiles.generic
end

---@param name string
---@param profile table
function M.register(name, profile)
  assert(type(name) == 'string' and name ~= '', 'journal profile name must be a string')
  assert(type(profile) == 'table', 'journal profile must be a table')
  M.profiles[name:lower()] = vim.deepcopy(profile)
end

---@return string[]
function M.names()
  local names = {}
  for name in pairs(M.profiles) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

return M