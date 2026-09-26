-- /qompassai/Diver/lua/ai/media/init.lua
-- Qompass AI Media Generation Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- HONESTY CONTRACT. Every backend in this module is probed at runtime,
-- never assumed. A backend is offered to the user only when its detect()
-- finds the real tool, model, or credential it needs:
--
--   tts-local    REAL: shells out to espeak-ng / piper / say when one is
--                actually installed. No engine, no audio -- the reason
--                says which install command fixes it.
--   image-openai REAL but gated: needs curl, OPENAI_API_KEY, and the
--                ported provider module ai.rose.provider.openai (Module 1).
--                Missing any of the three means unavailable, never a
--                faked image.
--   video-probe  HONEST STUB: probes for real local text-to-video CLIs
--                and always reports generation as unavailable, because no
--                generation path is implemented. ffmpeg is an encoder,
--                not a generator, and is labelled as such.
--
-- The coordinator (lua/ai/init.lua) wires this module in; require() here
-- only loads definitions, and setup() is idempotent.

local registry = require('ai.media.registry')

local M = {}

local did_setup = false

function M.setup()
    if did_setup then
        return
    end
    did_setup = true
    registry.register('tts-local', require('ai.media.tts_local').backend)
    registry.register('image-openai', require('ai.media.image_provider').backend)
    registry.register('video-probe', require('ai.media.video_probe').backend)
    require('ai.media.commands').setup()
end

return M
