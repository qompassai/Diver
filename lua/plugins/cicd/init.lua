-- qompassai/Diver/lua/plugins/cicd/init.lua
-- Qompass AI Diver CICD Plugin Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    require('plugins.cicd.ansible'),
    require('plugins.cicd.git'),
}