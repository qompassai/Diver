-- /qompassai/Diver/lua/ai/rose/providers/perplexity.lua
-- Perplexity provider descriptor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Sonar's search/chat surface is NOT the Agent API's custom function-calling surface.
-- Current official primary routes; configure endpoint=https://api.perplexity.ai/v1.

return {
    host = 'api.perplexity.ai',
    key_env = 'PERPLEXITY_API_KEY',
    apis = {
        agent = { path = '/agent', format = 'responses', tools = true },
        sonar = { path = '/sonar', format = 'chat', tools = false },
    },
}
