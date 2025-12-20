-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
return {
  {
    import = 'plugins.core'
  },
  {
    import = 'plugins.ai'
  },
  {
    {
      import = 'plugins.cloud'
    },
    {
      import = 'plugins.data'
    },
    {
      import = 'plugins.edu'
    },
    {
      import = 'plugins.cicd'
    },
    {
      import = 'plugins.lang'
    },
    {
      import = 'plugins.nav'
    },
    {
      import = 'plugins.ui'
    }
  }
}