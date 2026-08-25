-- /qompassai/Diver/after/plugin/mojo.lua
-- Qompass AI Diver After Plugin Mojo Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
M = {}
M.mojo = "%f:%l:%c: %t%*[^:]: %m,%Z%*[^ ]^"
M.mojo = M.mojo .. ",%EUnhandled exception caught during execution: At %f:%l:%c: %m"
return M