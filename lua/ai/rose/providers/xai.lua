-- /qompassai/Diver/lua/ai/rose/providers/xai.lua
-- xAI provider descriptor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

return {
    host = 'api.x.ai',
    key_env = 'XAI_API_KEY',
    apis = {
        responses = { path = '/responses', format = 'responses', tools = true },
        chat = { path = '/chat/completions', format = 'chat', tools = true },
    },
}
