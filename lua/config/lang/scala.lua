-- /qompassai/Diver/lua/config/scala.lua
-- Qompass AI Diver Scala Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
---@return string, string
function M.scala_version()
    local scalac = vim.fn.exepath('scalac')
    if scalac ~= '' then
        local handle = io.popen('scalac -version 2>&1')
        local result = handle and handle:read('*a') or ''
        if handle then handle:close() end
        local version = result:match('Scala compiler version ([%d%.]+)')
        return version or 'unknown', scalac
    end
    return 'unknown', ''
end
---@param opts? table
---@return table
function M.scala_cmp(opts)
    opts = opts or {}
    if vim.g.use_blink_cmp then
        return {
            sources = {{name = 'metals'}, {name = 'luasnip'}, {name = 'buffer'}},
            performance = {async = true, throttle = 50},
            appearance = {
                kind_icons = require('lazyvim.config').icons.kinds,
                nerd_font_variant = 'mono',
                use_nvim_cmp_as_default = false
            },
            completion = {
                accept = {auto_brackets = true},
                menu = {draw = {treesitter = {'lsp'}}},
                documentation = {auto_show = true}
            }
        }
    else
        return {
            sources = {
                {name = 'metals'}, {name = 'nvim_lsp'}, {name = 'luasnip'},
                {name = 'buffer'}
            },
            experimental = {ghost_text = true}
        }
    end
end
---@param opts? table
---@return table[]
function M.scala_nls(opts)
    opts = opts or {}
    local null_ls = require('null-ls')
    local b = null_ls.builtins
    return {b.formatting.scalafmt.with({extra_args = opts.scalafmt_args or {}})}
end
---@param opts? table
---@return table
function M.scala_conform(opts)
    opts = opts or {}
    return {
        formatters_by_ft = {scala = {'scalafmt'}, sbt = {'scalafmt'}},
        format_on_save = {
            lsp_fallback = true,
            timeout_ms = opts.format_timeout_ms or 500
        },
        format_after_save = opts.format_after_save
    }
end
---@param opts? table
function M.scala_lsp(opts)
    opts = opts or {}
    local metals = require('metals')
    local metals_config = metals.bare_config()
    metals_config.init_options.statusBarProvider = 'on'
    metals_config.settings = {
        showImplicitArguments = true,
        superMethodLensesEnabled = true,
        showInferredType = true,
        enableSemanticHighlighting = true,
        excludedPackages = {
            'akka.actor.typed.javadsl', 'com.github.swagger.akka.javadsl'
        }
    }
    metals_config.capabilities = opts.capabilities
    metals_config.on_attach = opts.on_attach
    local group = vim.api.nvim_create_augroup('nvim-metals', {clear = true})
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {'scala', 'sbt', 'java'},
        callback = function() metals.initialize_or_attach(metals_config) end,
        group = group
    })
end
---@param opts? table
---@return table
function M.scala_test(opts)
    opts = opts or {}
    return {
        adapters = {require('neotest-scala').setup({})},
        discovery = {
            enabled = true,
            filter_dir = function(name)
                return name ~= 'target' and name ~= '.bloop'
            end
        }
    }
end
---@param opts? table
---@return table
function M.scala_setup(opts)
    opts = opts or {}
    local scala_version, coursier_path = M.scala_version()
    if coursier_path then vim.env.COURSIER_PATH = coursier_path end
    vim.env.SCALA_VERSION = scala_version
    return {
        cmp = M.scala_cmp(opts),
        conform = M.scala_conform(opts),
        lsp = M.scala_lsp,
        nls = M.scala_nls(opts),
        version = scala_version,
        path = coursier_path,
        test = M.scala_test(opts)
    }
end
return M
