-- /qompassai/Diver/lua/ai/rose/config.lua
-- Resolved Rose configuration: defaults and validation (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Port of rose.nvim's config resolver, trimmed to what the folded-in
-- modules consume: trusted, workspace, ollama, providers, agent, flow,
-- mcp and checks. The speech/hub/webui/debug/diver/scip sections are
-- deliberately absent because those rose.nvim modules were not folded in.

local M = {}

---@class AiRoseOllamaConfig
---@field base_url string
---@field model string
---@field timeout integer
---@field allow_remote boolean
---@field transport string

---@class AiRoseProvidersConfig
---@field enabled boolean
---@field allow_cloud boolean
---@field provider string

---@class AiRoseAgentConfig
---@field max_iterations integer
---@field max_repair_rounds integer
---@field max_tool_calls integer
---@field max_tool_result integer
---@field max_context integer
---@field max_cycles integer

---@class AiRoseFlowConfig
---@field cmd string[]
---@field timeout integer
---@field bridge boolean

---@class AiRoseConfig
---@field trusted boolean
---@field workspace string
---@field ollama AiRoseOllamaConfig
---@field providers AiRoseProvidersConfig
---@field agent AiRoseAgentConfig
---@field flow AiRoseFlowConfig
---@field mcp table
---@field checks table<string, table>

-- Defaults template: workspace and agent.max_cycles are filled in by M.resolve,
-- so this table is intentionally not annotated as AiRoseConfig.
M.defaults = {
    trusted = false,
    ollama = {
        base_url = 'http://127.0.0.1:11434',
        model = 'qwen2.5-coder:7b',
        timeout = 120000,
        allow_remote = false,
        transport = 'auto',
    },
    providers = {
        enabled = false,
        allow_cloud = false,
        provider = 'ollama',
    },
    agent = {
        max_iterations = 6,
        max_repair_rounds = 1,
        max_tool_calls = 8,
        max_tool_result = 24000,
        max_context = 120000,
    },
    flow = { cmd = { 'flow', 'serve' }, timeout = 600000, bridge = true },
    mcp = { servers = {} },
    checks = {},
}

local CHECKS_COUNT_MAX = 256
local ARGV_ARGS_MAX = 64

---@param value any
---@param lo integer
---@param hi integer
---@param name string
local function integer(value, lo, hi, name)
    assert(type(name) == 'string', 'integer(): name must be a string')
    assert(lo <= hi, 'integer(): lo must not exceed hi')
    local range = name .. ' must be an integer in ' .. lo .. '..' .. hi
    assert(type(value) == 'number', range)
    assert(value % 1 == 0, range)
    assert(value >= lo, range)
    assert(value <= hi, range)
end

---@param configured string?
---@return string workspace  -- canonical absolute directory path
local function resolve_workspace(configured)
    local uv = vim.uv or vim.loop
    local root = configured or uv.cwd()
    assert(type(root) == 'string', 'workspace must be a path')
    assert(root ~= '', 'workspace must be a path')
    root = vim.fn.fnamemodify(root, ':p'):gsub('[/\\]+$', '')
    if root == '' then
        root = '/'
    end
    local real = assert(uv.fs_realpath(root), 'workspace does not exist')
    local stat = uv.fs_stat(real)
    assert(stat and stat.type == 'directory', 'workspace must be a directory')
    return real
end

---@param checks table
local function validate_checks(checks)
    assert(type(checks) == 'table', 'checks must be a table of named commands')
    local count = 0
    for name, check in pairs(checks) do
        count = count + 1
        assert(count <= CHECKS_COUNT_MAX, 'checks must define at most ' .. CHECKS_COUNT_MAX)
        assert(type(name) == 'string', 'checks must be a table of named configurations')
        assert(type(check) == 'table', 'checks must be a table of named configurations')
        if check.filetypes ~= nil then
            assert(type(check.filetypes) == 'table', 'check.filetypes must be an array')
        end
    end
end

-- Bundled read-only LSP helpers as default MCP servers.
---@param workspace string
---@return table<string, table>
local function mcp_defaults(workspace)
    local config_home = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config')
    return {
        mcpls = {
            cmd = {
                'mcpls',
                '--config',
                vim.fs.joinpath(config_home, 'mcpls', 'mcpls.toml'),
            },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'lsp_hover',
                'lsp_definition',
                'lsp_references',
                'lsp_diagnostics',
                'lsp_document_symbols',
                'lsp_workspace_symbols',
                'lsp_completion',
                'lsp_signature_help',
                'lsp_inlay_hints',
            },
        },
        mcp_rust = {
            cmd = {
                'mcp-language-server',
                '--workspace',
                workspace,
                '--lsp',
                'rust-analyzer',
            },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'definition',
                'references',
                'diagnostics',
                'hover',
            },
        },
    }
end

---@param argv any
---@param name string
local function validate_argv(argv, name)
    assert(type(argv) == 'table' and #argv > 0 and #argv <= ARGV_ARGS_MAX, name .. ' must be a nonempty argv array')
    for index, value in ipairs(argv) do
        assert(
            type(value) == 'string' and value ~= '' and not value:find('\0', 1, true),
            name .. ' has invalid argument ' .. index
        )
    end
end

---@param mcp table
local function validate_mcp(mcp)
    assert(type(mcp) == 'table', 'mcp must be a configuration table')
    assert(type(mcp.servers) == 'table', 'mcp.servers must be a table of named servers')
    for name, server in pairs(mcp.servers) do
        assert(type(name) == 'string' and name ~= '', 'mcp server names must be nonempty')
        assert(type(server) == 'table', 'mcp.' .. name .. ' must be a table')
        local cmd = rawget(server, 'cmd')
        assert(type(cmd) == 'table', 'mcp.' .. name .. '.cmd must be an argv array')
        validate_argv(cmd, 'mcp.' .. name .. '.cmd')
        local trusted = rawget(server, 'trusted')
        assert(type(trusted) == 'boolean', 'mcp.' .. name .. '.trusted must be a boolean')
        local readonly = rawget(server, 'readonly')
        assert(type(readonly) == 'boolean', 'mcp.' .. name .. '.readonly must be a boolean')
        local timeout = rawget(server, 'timeout')
        assert(type(timeout) == 'number', 'mcp.' .. name .. '.timeout must be an integer')
        integer(timeout, 1, 3600000, 'mcp.' .. name .. '.timeout')
        local allowtools = rawget(server, 'allowtools')
        if allowtools ~= nil then
            assert(type(allowtools) == 'table', 'mcp.' .. name .. '.allowtools must be an array')
            for index, tool in ipairs(allowtools) do
                assert(
                    type(tool) == 'string' and tool ~= '',
                    'mcp.' .. name .. '.allowtools has invalid tool ' .. index
                )
            end
        end
        local env = rawget(server, 'env')
        if env ~= nil then
            assert(type(env) == 'table', 'mcp.' .. name .. '.env must be a table')
            for key, value in pairs(env) do
                assert(type(key) == 'string' and key ~= '', 'mcp.' .. name .. '.env has invalid name')
                assert(
                    type(value) == 'string' and not value:find('\0', 1, true),
                    'mcp.' .. name .. '.env has invalid value'
                )
            end
        end
    end
end

-- Deep-merge user options over the defaults and validate every bound.
-- Raises (use pcall) on invalid configuration.
---@param opts? table partial options; omitted fields keep defaults
---@return AiRoseConfig config
function M.resolve(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'Rose setup options must be a table')

    local config = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
    if opts.agent and opts.agent.max_cycles ~= nil then
        integer(opts.agent.max_cycles, 1, 4, 'agent.max_cycles')
        if opts.agent.max_repair_rounds == nil then
            config.agent.max_repair_rounds = opts.agent.max_cycles - 1
        end
    end

    assert(type(config.trusted) == 'boolean', 'trusted must be a boolean')
    config.workspace = resolve_workspace(config.workspace)
    config.mcp.servers = vim.tbl_deep_extend('keep', config.mcp.servers or {}, mcp_defaults(config.workspace))

    integer(config.ollama.timeout, 1, 3600000, 'ollama.timeout')
    integer(config.agent.max_iterations, 1, 30, 'agent.max_iterations')
    integer(config.agent.max_repair_rounds, 0, 3, 'agent.max_repair_rounds')
    config.agent.max_cycles = config.agent.max_repair_rounds + 1
    integer(config.agent.max_tool_calls, 1, 32, 'agent.max_tool_calls')
    integer(config.agent.max_tool_result, 256, 1048576, 'agent.max_tool_result')
    integer(config.agent.max_context, 1024, 4194304, 'agent.max_context')
    integer(config.flow.timeout, 1, 3600000, 'flow.timeout')
    validate_mcp(config.mcp)

    assert(type(config.ollama.model) == 'string', 'ollama.model is required')
    assert(config.ollama.model ~= '', 'ollama.model is required')
    assert(type(config.ollama.base_url) == 'string', 'ollama.base_url must be a string')
    assert(type(config.providers) == 'table', 'providers must be a configuration table')

    validate_checks(config.checks)
    assert(type(config.workspace) == 'string', 'resolved workspace must be a string')

    -- Assemble the resolved config explicitly: tbl_deep_extend returns a plain
    -- table, so the class shape is declared here where every field is filled.
    ---@type AiRoseAgentConfig
    local agent = {
        max_iterations = config.agent.max_iterations,
        max_repair_rounds = config.agent.max_repair_rounds,
        max_tool_calls = config.agent.max_tool_calls,
        max_tool_result = config.agent.max_tool_result,
        max_context = config.agent.max_context,
        max_cycles = config.agent.max_cycles,
    }
    ---@type AiRoseConfig
    local resolved = {
        trusted = config.trusted,
        workspace = config.workspace,
        ollama = config.ollama,
        providers = config.providers,
        agent = agent,
        flow = config.flow,
        mcp = config.mcp,
        checks = config.checks,
    }
    return resolved
end

---@param opts? table
---@return AiRoseConfig config
function M.setup(opts)
    M.options = M.resolve(opts)
    return M.options
end

return M
