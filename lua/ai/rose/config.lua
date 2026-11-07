-- /qompassai/Diver/lua/ai/rose/config.lua
-- Resolved Rose configuration: defaults and validation (Tiger Style)
---@module 'ai.rose.config'
-- Port of rose.nvim's config resolver, trimmed to what the folded-in
-- modules consume: trusted, workspace, rose, providers, agent, flow,
-- mcp and checks. The speech/hub/webui/debug/diver/scip sections are
-- deliberately absent because those rose.nvim modules were not folded in.

local M = {}

---@class AiRoseBackendConfig
---@field base_url string
---@field model string
---@field timeout integer
---@field allow_remote boolean
---@field transport string

---@alias AiRoseOllamaConfig AiRoseBackendConfig

---@class AiRoseProvidersConfig
---@field enabled boolean
---@field allow_cloud boolean
---@field provider string

---@class AiRoseSpeculativeConfig
---@field enabled boolean default false; no behavior changes when false
---@field host string llama.cpp server host for speculative decoding
---@field port integer llama.cpp server port
---@field draft_model string draft model path, required when enabled
---@field n_draft integer draft tokens per step, 1..16
---@field allow_remote boolean opt in to non-loopback hosts; enforced by ai.inference.speculative
---@field kv table declared KV precision contract for the server; checked by ai.inference.kv_policy when enabled

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
---@field rose AiRoseBackendConfig
---@field ollama AiRoseBackendConfig legacy alias of rose; the same table
---@field providers AiRoseProvidersConfig
---@field speculative AiRoseSpeculativeConfig
---@field agent AiRoseAgentConfig
---@field flow AiRoseFlowConfig
---@field mcp table
---@field checks table<string, table>

-- Defaults template: workspace and agent.max_cycles are filled in by M.resolve,
-- so this table is intentionally not annotated as AiRoseConfig.
M.defaults = {
    trusted = false,
    rose = {
        base_url = 'http://127.0.0.1:11434',
        model = 'qwen2.5-coder:7b',
        timeout = 120000,
        allow_remote = false,
        transport = 'auto',
    },
    providers = {
        enabled = false,
        allow_cloud = false,
        provider = 'rose',
    },
    speculative = {
        enabled = false,
        host = '127.0.0.1',
        port = 8080,
        draft_model = '',
        n_draft = 5,
        allow_remote = false,
        kv = {},
    },
    agent = {
        max_iterations = 6,
        max_repair_rounds = 1,
        max_tool_calls = 8,
        max_tool_result = 24000,
        max_context = 120000,
    },
    flow = { cmd = { 'phlow', 'serve' }, timeout = 600000, bridge = true },
    mcp = { servers = {} },
    checks = {},
}

local ARGV_ARGS_MAX = 64
local CHECKS_COUNT_MAX = 256

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
    local uv = vim.uv or vim.uv
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

-- Default MCP servers: the bundled read-only LSP helpers plus the
-- deployed estate fleet (D-879, 2026-11-03). Estate servers are
-- modern-era only (protocol 2026-07-28, D-113): they refuse a legacy
-- initialize with a typed -32022. Every estate entry is gated to the
-- read-only tools validated against the deployed build; write and
-- execute tools are deliberately absent from allowtools, so Rose can
-- never call them. Servers without a deployed binary on this machine
-- (ardor, fathom, lumen, phaedrus, torogao) are not registered: a
-- configured-but-absent server is a defect, not a placeholder.
---@param workspace string
---@return table<string, table>
local function mcp_defaults(workspace)
    local config_home = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config')
    local home = vim.env.HOME
    return {
        -- Bloch 0.4.1: fleet memory/tracker server; binds to the client
        -- workspace (servers.lua spawns with cwd = workspace).
        bloch = {
            cmd = { vim.fs.joinpath(home, '.cargo/bin/bloch'), 'serve' },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'idea_lookup',
                'lessons_search',
                'memory_get',
                'memory_search',
                'roadmap_rollup',
                'roadmap_state',
                'tracker_rollup',
                'tracker_state',
            },
        },
        -- Eigenstyle 1.0.0 (mcpb bundle deployed under mcpb-stage-1.0):
        -- voice-profile server; ingest and fingerprint writes stay ungated.
        eigenstyle = {
            cmd = { vim.fs.joinpath(home, '.local/share/pax/mcpb-stage-1.0/eigenstyle/eigenstyle') },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'check_draft',
                'get_exemplars',
                'get_profile',
                'list_corpus',
            },
        },
        -- Lupin 1.0.0: opportunity ledger; the submit tool stays ungated.
        lupin = {
            cmd = { vim.fs.joinpath(home, '.local/share/pax/mcpb-stage-1.0/lupin/lupin') },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'capability_list',
                'capability_match',
                'opportunity_get',
                'opportunity_list',
                'pipeline_summary',
            },
        },
        -- Lumen 2.0.0 (~/.local/bin/lumen; built from lumen main
        -- bd190450 + D-1041): conversion factory + the generation lane
        -- folded in (D-143) and renamed to lumen terminology (D-1041).
        -- Read-only status tools plus the two generation tools
        -- (lumen_txt2img, lumen_img2img) gated here per D-1057
        -- (2026-11-06); the standalone atelier registration was
        -- retired 2026-11-05 (D-1009).
        lumen = {
            cmd = { vim.fs.joinpath(home, '.local/bin/lumen') },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'lumen_img2img',
                'lumen_models',
                'lumen_status',
                'lumen_txt2img',
            },
        },
        -- mcpls 0.7.0: the allowtools below were corrected 2026-11-03
        -- (D-879) to the tool names the deployed server actually
        -- serves (get_*/workspace_symbol_search); the previous lsp_*
        -- names matched nothing, so every call would have been
        -- refused by the servers.lua allowlist even with the server
        -- running. Write-shaped tools (format_*, rename_symbol,
        -- restart_server) stay ungated.
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
                'get_completions',
                'get_definition',
                'get_diagnostics',
                'get_document_symbols',
                'get_hover',
                'get_inlay_hints',
                'get_references',
                'get_signature_help',
                'workspace_symbol_search',
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
        -- Neemu 1.0.0: media-ingest RE server. Its read tools require a
        -- registered work id; extraction/ingest tools stay ungated.
        neemu = {
            cmd = { vim.fs.joinpath(home, '.local/bin/neemu'), '--profile', 'image' },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'neemu_list_records',
                'neemu_segment_scene',
            },
        },
        -- Periscope 1.0.0: broker into the live editor. run_format writes
        -- files and run_lint executes linters, so both stay ungated, as do
        -- the attention mutators.
        periscope = {
            cmd = { vim.fs.joinpath(home, '.local/bin/periscope') },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'broker_status',
                'get_definition',
                'get_diagnostics',
                'get_document_symbols',
                'get_hover',
                'get_references',
                'list_dap',
                'list_formatters',
                'list_linters',
                'list_servers',
            },
        },
        -- Phlow (server name "flow"): the agent runtime's own MCP face.
        -- flow_run executes tasks and flow_check runs configured checks,
        -- so only the status tool is gated here.
        phlow = {
            cmd = { vim.fs.joinpath(home, '.local/bin/phlow'), 'serve' },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'flow_status',
            },
        },
        -- Salesforce DX, read-only: SOQL queries, org listing, username
        -- resolution via the official @salesforce/mcp server (version
        -- pinned; npx fetches it on first run). The org comes from
        -- SALESFORCE_MCP_ORG so other machines can override it; the
        -- fallback is the operator's own connected DE org. Write tools
        -- (deploy_metadata, resume_tool_operation) are installed by the
        -- toolsets but deliberately absent from allowtools, so Rose can
        -- never call them. Vetted 2026-10-05: 6 tools listed, no
        -- prompt-injection findings (4 cross-tool vocabulary correlations,
        -- all benign shared domain words).
        salesforce_dx = {
            cmd = {
                'npx',
                '-y',
                '@salesforce/mcp@0.30.15',
                '-o',
                vim.env.SALESFORCE_MCP_ORG or 'agentforce-de',
                '--toolsets',
                'core',
                'data',
                'orgs',
            },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'get_username',
                'list_all_orgs',
                'run_soql_query',
            },
        },
        -- Seahawk 1.0.0: Unreal MCP broker (lab-only, token auth inside
        -- its own config file, never copied here). Only the read-only
        -- status/surface/oplog tools are gated; the gui.* and execute
        -- surface stays ungated.
        seahawk = {
            cmd = {
                vim.fs.joinpath(home, '.local/bin/seahawk'),
                vim.fs.joinpath(config_home, 'seahawk', 'seahawk.toml'),
            },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'seahawk_oplog',
                'seahawk_status',
                'seahawk_surface',
            },
        },
        -- Slipway 1.0.0 (mcpb bundle deployed under mcpb-stage-1.0,
        -- invoked with the bundle's own config, per its manifest):
        -- Android release server; build/sign/release tools stay ungated.
        slipway = {
            cmd = {
                vim.fs.joinpath(home, '.local/share/pax/mcpb-stage-1.0/slipway/slipway'),
                '--config',
                vim.fs.joinpath(home, '.local/share/pax/mcpb-stage-1.0/slipway/config.toml'),
            },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'slipway_bundle_check',
                'slipway_inspect',
                'slipway_release_check',
                'slipway_status',
                'slipway_toolchain',
                'slipway_verify',
            },
        },
        -- Theodolite 0.2.2: headless LSP bridge; read-only by design.
        -- The bridge config pins rust-analyzer (deployed 2026-11-03,
        -- ~/.local/share/theodolite/bridge.toml). session_restart
        -- mutates session state and stays ungated. First calls start
        -- the pinned language server, hence the longer timeout.
        theodolite = {
            cmd = {
                vim.fs.joinpath(home, '.local/bin/theodolite'),
                '--config',
                vim.fs.joinpath(home, '.local/share/theodolite/bridge.toml'),
            },
            trusted = true,
            readonly = true,
            timeout = 120000,
            allowtools = {
                'code_actions',
                'declaration',
                'definition',
                'diagnostics',
                'document_symbols',
                'hover',
                'implementation',
                'references',
                'rename_preview',
                'session_status',
                'type_definition',
                'workspace_symbols',
            },
        },
        -- Torori 1.0.0: voice/SFX asset server; fetch, ingest, generate
        -- and render tools stay ungated.
        torori = {
            cmd = { vim.fs.joinpath(home, '.local/bin/torori'), '--profile', 'bundles,library,voice' },
            trusted = true,
            readonly = true,
            timeout = 60000,
            allowtools = {
                'torori_bundle_list',
                'torori_bundle_validate',
                'torori_catalogue_get',
                'torori_catalogue_search',
                'torori_catalogue_stats',
                'torori_library_manifest',
                'torori_library_search',
                'torori_pair_list',
                'torori_pair_validate',
                'torori_status',
                'torori_voice_list',
                'torori_voice_qc',
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

    -- Legacy compat (2026-10 rename): the backend section was named `ollama`
    -- before the provider took the rose name. A user-supplied `ollama`
    -- section is read as the `rose` section; explicit `rose` fields win
    -- over legacy ones. The resolved config aliases `ollama` to the same
    -- table (see the assembly below), so readers of the old key keep
    -- seeing live values.
    if opts.ollama ~= nil then
        assert(type(opts.ollama) == 'table', 'ollama must be a configuration table')
        local normalized = {}
        for key, value in pairs(opts) do
            normalized[key] = value
        end
        normalized.rose = vim.tbl_deep_extend('force', vim.deepcopy(opts.ollama), opts.rose or {})
        normalized.ollama = nil
        opts = normalized
    end

    local config = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
    -- A saved config may still select the provider by its legacy id
    -- 'ollama'; that id names this backend, so normalize it to 'rose'.
    if type(config.providers) == 'table' and config.providers.provider == 'ollama' then
        config.providers.provider = 'rose'
    end
    if opts.agent and opts.agent.max_cycles ~= nil then
        integer(opts.agent.max_cycles, 1, 4, 'agent.max_cycles')
        if opts.agent.max_repair_rounds == nil then
            config.agent.max_repair_rounds = opts.agent.max_cycles - 1
        end
    end

    assert(type(config.trusted) == 'boolean', 'trusted must be a boolean')
    config.workspace = resolve_workspace(config.workspace)
    config.mcp.servers = vim.tbl_deep_extend('keep', config.mcp.servers or {}, mcp_defaults(config.workspace))

    integer(config.rose.timeout, 1, 3600000, 'rose.timeout')
    integer(config.agent.max_iterations, 1, 30, 'agent.max_iterations')
    integer(config.agent.max_repair_rounds, 0, 3, 'agent.max_repair_rounds')
    config.agent.max_cycles = config.agent.max_repair_rounds + 1
    integer(config.agent.max_tool_calls, 1, 32, 'agent.max_tool_calls')
    integer(config.agent.max_tool_result, 256, 1048576, 'agent.max_tool_result')
    integer(config.agent.max_context, 1024, 4194304, 'agent.max_context')
    integer(config.flow.timeout, 1, 3600000, 'flow.timeout')
    validate_mcp(config.mcp)

    assert(type(config.rose.model) == 'string', 'rose.model is required')
    assert(config.rose.model ~= '', 'rose.model is required')
    assert(type(config.rose.base_url) == 'string', 'rose.base_url must be a string')
    assert(type(config.providers) == 'table', 'providers must be a configuration table')
    assert(type(config.speculative) == 'table', 'speculative must be a configuration table')
    assert(type(config.speculative.enabled) == 'boolean', 'speculative.enabled must be a boolean')
    assert(type(config.speculative.allow_remote) == 'boolean', 'speculative.allow_remote must be a boolean')
    if config.speculative.enabled then
        assert(
            type(config.speculative.host) == 'string' and config.speculative.host ~= '',
            'speculative.host is required when speculative.enabled'
        )
        integer(config.speculative.port, 1, 65535, 'speculative.port')
        assert(
            type(config.speculative.draft_model) == 'string' and config.speculative.draft_model ~= '',
            'speculative.draft_model is required when speculative.enabled'
        )
        integer(config.speculative.n_draft, 1, 16, 'speculative.n_draft')
        assert(type(config.speculative.kv) == 'table', 'speculative.kv must be a table')
        local kv_policy = require('ai.inference.kv_policy')
        local violations, verr = kv_policy.validate(config.speculative.kv)
        assert(verr == nil, 'speculative.kv: ' .. tostring(verr))
        assert(#violations == 0, 'speculative.kv violates KV precision policy: ' .. table.concat(violations, '; '))
    end

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
        rose = config.rose,
        ollama = config.rose, -- legacy alias: the same table, so config.ollama readers see live values
        providers = config.providers,
        speculative = config.speculative,
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
