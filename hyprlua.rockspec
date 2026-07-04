-- /qompassai/lua/lua_ls/addons/hyprlua/hl.rockspec
-- Qompass AI HyprLua LuaRocks Rockspec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
rockspec_format = '3.0'
package = 'hyprlua'
version = '0.1.0-1'
description = {
    detailed = [[
        LuaCATS type annotations and lua_ls addon definitions for
        Hyprland 0.55+'s Lua configuration API. Goal is to provide full
        completions, hover docs, and type-checking for the hl.*
        global namespace, dispatchers, layout API, and events.
    ]],
    homepage = 'https://github.com/qompassai/hyprlua',
    issues_url = 'https://github.com/qompassai/hyprlua/issues',
    labels = {
        'annotations',
        'hyprland',
        'luacats',
        'lua-language-server',
'lua_ls',
        'types',
        'wayland',
    },
    license = 'Apache-2.0',
    maintainer = 'Qompass AI <map@qompass.ai>',
    summary = 'LuaCATS annotations for the Hyprland 0.55+ Lua config API',
}
source = {
    branch = 'main',
    url = 'git+https://github.com/qompassai/hyprlua',
}

supported_platforms = {
    'linux',
}

dependencies = {
    'lua >= 5.4',
}
build_dependencies = {
    'luarocks-build-addon',
}

test_dependencies = {
    'busted >= 2.0',
}

build = {
    type = 'lls-addon',
    copy_directories = {
        'library',
    },

    settings = {
        ['diagnostics.disable'] = {
            'undefined-global',
        },
        ['diagnostics.globals'] = {
            'hl',
        },
        ['diagnostics.groupSeverity'] = {
            await = 'Error',
            ['luadoc'] = 'Warning',
            ['type-check'] = 'Warning',
        },
        ['runtime.builtin'] = {
            utf8 = 'enable',
        },
        ['runtime.version'] = 'Lua 5.4',
        ['workspace.preloadFileSize'] = 5000,
    },
}
test = {
    type = 'busted',
}
