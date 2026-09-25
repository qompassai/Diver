-- /qompassai/Diver/after/plugin/mojo.lua
-- Qompass AI Diver After Plugin Mojo Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- local: ftplugin chunks are sourced, not required, so a bare `M = {}`
-- installs a persistent _G entry every time a buffer of this filetype
-- opens (and every sibling ftplugin doing `M = {}` clobbers it).
-- No file reads these globals; verified by repo-wide grep.
local M = {}
M.mojo = '%f:%l:%c: %t%*[^:]: %m,%Z%*[^ ]^'
M.mojo = M.mojo .. ',%EUnhandled exception caught during execution: At %f:%l:%c: %m'
return M
