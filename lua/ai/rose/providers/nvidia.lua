-- /qompassai/Diver/lua/ai/rose/providers/nvidia.lua
-- NVIDIA NIM provider descriptor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

return {
    host = 'integrate.api.nvidia.com',
    key_env = 'NVIDIA_API_KEY',
    apis = { chat = { path = '/chat/completions', format = 'chat', tools = true } },
}
