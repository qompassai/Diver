-- /qompassai/Diver/plugin/dir.lua
-- Qompass AI Dir
---@module 'plugin.dir'
-- Compatibility file for the retired local directory-browser shim.
-- Neovim 0.13 supplies the browser in $VIMRUNTIME/plugin/dir.lua.
-- Do not set its loaded flag or register replacement directory autocommands here.
-- config.nav.nt loads the native plugin from the active runtime when needed.
-- This empty table also keeps existing require('plugins.dir') calls valid.
-- Replace any old copy in plugin/dir.lua or lua/plugins/dir.lua with this file.

return {}
