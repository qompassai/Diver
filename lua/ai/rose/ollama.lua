-- /qompassai/Diver/lua/ai/rose/ollama.lua
-- Legacy module path for the rose chat backend (Tiger Style)
---@module 'ai.rose.ollama'
-- The backend moved to ai.rose.backend when the provider took the rose
-- name (2026-10). This shim keeps existing requires of 'ai.rose.ollama'
-- working; new code should require 'ai.rose.backend' directly.

return require('ai.rose.backend')
