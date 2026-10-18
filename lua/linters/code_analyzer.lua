-- /qompassai/Diver/lua/linters/code_analyzer.lua
-- Qompass AI Diver Salesforce Code Analyzer (factory re-export)
---@module 'linters.code_analyzer'
--
-- ELI5: This module used to carry its own full copy of the Salesforce
-- Code Analyzer linter factory. Two copies of the same tricky code meant
-- a bug fixed in one copy stayed broken in the other (that is how the
-- file:// location crash and the giant error-message bug survived here).
-- Now it is a thin re-export of the single factory in
-- linters._salesforce-code-analyzer: every fix lands here automatically.
-- The public API is unchanged: M.new({ name = ..., selector = ... }).
--
---@source https://github.com/Flow-Scanner

local factory = require('linters._salesforce-code-analyzer')

assert(type(factory) == 'table', 'linters._salesforce-code-analyzer must return a module table')
assert(type(factory.new) == 'function', 'linters._salesforce-code-analyzer must expose new(options)')

local M = {}

---@param options SalesforceAnalyzerOptions
---@return Linter
function M.new(options)
    return factory.new(options)
end

return M
