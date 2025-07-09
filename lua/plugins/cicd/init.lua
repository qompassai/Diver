-- /qompassai/Diver/lua/plugins/cicd/init.lua
-- Qompass AI CICD Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

return {
	require('plugins.cicd.ansible'),
	require('plugins.cicd.containers'),
	require('plugins.cicd.filetype'),
	require('plugins.cicd.git'),
	require('plugins.cicd.mail'),
	require('plugins.cicd.shell')
}
