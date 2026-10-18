-- /qompassai/lua/scip/lightning-flow-scanner.lua
-- Qompass AI Diver Native Salesforce Lightning Flow Scanner
---@module 'linters.lightning-flow-scanner'
local ok, factory = pcall(require, 'linters._salesforce-code-analyzer')
if not ok then
    ---@type LinterUnavailable
    return { unavailable = 'linters._salesforce-code-analyzer' }
end
return factory.new({
    name = 'lightning-flow-scanner',
    selector = 'flow:Recommended',
})
