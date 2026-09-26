-- /qompassai/Diver/lua/ai/rose/providers/openai.lua
-- OpenAI provider descriptor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

return {
    host = 'api.openai.com',
    key_env = 'OPENAI_API_KEY',
    apis = {
        responses = { path = '/responses', format = 'responses', tools = true },
        chat = { path = '/chat/completions', format = 'chat', tools = true },
    },
}
