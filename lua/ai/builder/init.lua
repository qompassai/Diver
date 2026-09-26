-- /qompassai/Diver/lua/ai/builder/init.lua
-- Qompass AI Interactive Application Builder: Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Iterative, interactive full-application builder. The pipeline:
--
--   menu.lua      Gathers a BuilderSpec through vim.ui.select menus
--                 (project type, language, features multi-pick, model)
--                 plus vim.ui.input free write-in fields, then validates
--                 it with menu.validate/1.
--   pipeline.lua  Runs plan -> generate -> validate -> review. Every
--                 stage produces an artifact and STOPS for an explicit
--                 yes/edit/abort confirmation before the next stage
--                 runs. Generation calls ai.rose's plan()/generate()
--                 entry points; when the backend is absent or the model
--                 is unconfigured the pipeline reports "generation
--                 backend unavailable" and stops instead of inventing
--                 output. Sessions persist to a bounded JSON
--                 file under stdpath('data') after each stage.
--   writer.lua    Writes generated files only after the review stage is
--                 confirmed: mkdir -p, per-file overwrite confirmation,
--                 atomic temp+rename writes, and a created/skipped report.
--                 Paths are contained to the target directory.
--   commands.lua  Registers :AiBuild (new session) and :AiBuildResume
--                 (resume last session), plus <LocalLeader>ab / aB.
--
-- Requiring this module has no side effects; setup() is idempotent.

local M = {}

local configured = false

function M.setup()
    if configured then
        return
    end
    configured = true
    require('ai.builder.commands')
end

return M
