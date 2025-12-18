-- /qompassai/Diver/lua/config/core/core/neotest.lua
-- Qompass AI Diver Neotest Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'config.core.neotest'
local M = {}

M.opts = {
    default_strategy = 'integrated',
    strategies = {
        integrated = {
            width = 120,
        },
    },
    adapters = {
        require('neotest-bash')({ binary = '/usr/bin/bash' }),
        require('neotest-playwright')({ config_file = 'playwright.config.ts' }),
        require('neotest-plenary')({
            test_dir = 'tests/plenary',
        }),
        require('neotest-python')({
            dap = { justMyCode = false },
            args = { '--log-level', 'DEBUG' },
            runner = 'pytest',
            python = '.venv/bin/python',
            pytest_discover_instances = true,
        }),
        require('neotest-scala')({
            test_runner = 'sbt',
        }),
        require('neotest-vitest')({
            command = { 'vitest run' },
        }),
    },
    require('neotest-zig')({
        zig_path = (function()
            local home = vim.fn.expand('~')
            local default = home .. '/.local/bin/zig'
            local fallback = '/usr/bin/zig'
            if vim.uv.fs_stat(default) then
                return default
            else
                return fallback
            end
        end)(),
    }),
    consumers = {},
    diagnostic = {
        enabled = true,
        severity = vim.diagnostic.severity.ERROR,
    },
    discovery = {
        enabled = true,
        concurrent = 0,
        max_files = 100,
    },
    floating = {
        border = 'rounded',
        max_height = 0.9,
        max_width = 0.9,
        options = {},
    },
    highlights = {
        adapter_name = 'NeotestAdapterName',
        border = 'NeotestBorder',
        dir = 'NeotestDir',
        expand_marker = 'NeotestExpandMarker',
        failed = 'NeotestFailed',
        file = 'NeotestFile',
        focused = 'NeotestFocused',
        indent = 'NeotestIndent',
        marked = 'NeotestMarked',
        namespace = 'NeotestNamespace',
        passed = 'NeotestPassed',
        running = 'NeotestRunning',
        select_win = 'NeotestWinSelect',
        skipped = 'NeotestSkipped',
        target = 'NeotestTarget',
        test = 'NeotestTest',
        unknown = 'NeotestUnknown',
        watching = 'NeotestWatching',
    },
    icons = {
        child_indent = '│',
        child_prefix = '├',
        collapsed = '─',
        expanded = '╮',
        failed = '',
        final_child_indent = ' ',
        final_child_prefix = '╰',
        non_collapsible = '─',
        passed = '',
        running = '',
        skipped = '',
        unknown = '',
        watching = '',
    },
    jump = {
        enabled = true,
    },
    log_level = vim.log.levels.INFO,
    output = {
        enabled = true,
        open_on_run = 'short',
    },
    projects = {},
    output_panel = {
        enabled = true,
        open = 'botright split | resize 15',
    },
    quickfix = {
        enabled = true,
        open = true,
    },
    run = {
        enabled = true,
        strategy = 'integrated',
    },
    running = {
        concurrent = true,
    },
    state = {
        enabled = true,
    },
    status = {
        enabled = true,
        signs = true,
        virtual_text = true,
    },
    summary = {
        animated = true,
        enabled = true,
        expand_errors = true,
        count = true,
        follow = true,
        mappings = {
            attach = 'a',
            clear_marked = 'M',
            clear_target = 'T',
            debug = 'd',
            debug_marked = 'D',
            expand = { '<CR>', '<2-LeftMouse>' },
            expand_all = 'e',
            jumpto = 'i',
            mark = 'm',
            next_failed = 'J',
            output = 'o',
            prev_failed = 'K',
            run = 'r',
            run_marked = 'R',
            short = 'O',
            stop = 'u',
            stop_marked = 'U',
            target = 't',
            watch = 'w',
        },
        open = 'botright vsplit | vertical resize 50',
        show_errors = true,
        show_output = true,
    },
    watch = {
        enabled = true,
        run = true,
        symbol_queries = {},
    },
}
M.setup = function() end
return M
