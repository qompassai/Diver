-- /qompassai/Diver/lua/ai/mcp/declared_servers.lua
-- Qompass AI Declared MCP Servers (Tiger Style)
---@module 'ai.mcp.declared_servers'
--
-- Version-controlled MCP server declarations. This file is the source of
-- truth for the fleet: it travels with the config, diffs in review, and
-- loads identically on every machine.
--
-- Secret-free by construction: any credential a server needs is a *reference*
-- (see ai.mcp.secrets), resolved at spawn time from pass, the environment,
-- or a command. Values never appear here, in the persisted registry, or in
-- logs. Each entry passes through registry.validate() on load; a bad entry
-- is reported and skipped, never fatal.
--
-- Fields per entry: name, command (absolute path), args (argv array),
-- env (non-secret variables only), secrets (variable -> ref), cwd,
-- enabled. Entries added via :McpAdd live in the persisted registry and win
-- over a same-named declaration.

return {
    {
        name = 'bloch',
        command = '/home/phaedrus/.cargo/bin/bloch',
        args = { 'serve' },
        enabled = true,
    },
    {
        name = 'broadside',
        command = '/home/phaedrus/.cargo/bin/broadside-mcp',
        args = {},
        enabled = true,
    },
    {
        name = 'eigenstyle',
        command = '/home/phaedrus/.local/share/pax/mcpb-stage-1.0/eigenstyle/eigenstyle',
        args = {},
        enabled = true,
    },
    {
        name = 'git',
        command = '/usr/bin/uvx',
        args = { 'mcp-server-git@2026.10.10' },
        enabled = true,
    },
    {
        name = 'fetch',
        command = '/usr/bin/uvx',
        args = { 'mcp-server-fetch@2026.10.10' },
        enabled = true,
    },
    {
        -- Fathom (Matt's own clean-room reverse-engineering MCP,
        -- Rust, estate-built): takes the RE seat from REA under
        -- D-1361 (2026-11-11). REA is third-party code whose
        -- modern surface does not implement `ping` -- a true-positive
        -- conformance FAIL of record 2026-11-11, no estate-side fix.
        -- D-1361: --profile full is pinned deliberately (the D-954
        -- pattern, as on seahawk below). This seat is the specialist
        -- RE route; since the D-910 diet landed under D-1355, a
        -- selector-less launch serves the core profile only (8
        -- tools). The full catalog is 192 tools at the D-1355
        -- census. No credentials required.
        name = 'fathom',
        command = '/home/phaedrus/.GH/Qompass/fathom/target/release/fathom',
        args = { 'serve', '--profile', 'full' },
        enabled = true,
    },
    {
        -- Local binary (no docker): /usr/bin/github-mcp-server over stdio.
        -- The token is Matt's fine-grained PAT in pass at 'gh/pat', resolved
        -- at spawn time and never stored here. Full default toolsets: no
        -- --read-only flag and no toolset restriction args.
        name = 'github',
        command = '/usr/bin/github-mcp-server',
        args = { 'stdio' },
        secrets = {
            GITHUB_PERSONAL_ACCESS_TOKEN = { provider = 'pass', path = 'gh/pat' },
        },
        enabled = true,
    },
    {
        name = 'lumen',
        command = '/home/phaedrus/.local/bin/lumen',
        args = {},
        enabled = true,
    },
    {
        name = 'lupin',
        command = '/home/phaedrus/.local/share/pax/mcpb-stage-1.0/lupin/lupin',
        args = {},
        enabled = true,
    },
    {
        -- NVIDIA CUDA docs (first-party CUDA documentation and code
        -- examples), hosted by NVIDIA as a streamable-HTTP MCP server.
        -- This config's MCP client is stdio-only, so the declaration
        -- bridges through mcp-remote (pinned, never @latest): it proxies
        -- stdio to the HTTPS endpoint and owns the OAuth flow, with
        -- tokens stored under ~/.mcp-auth. The first connection needs
        -- an interactive NVIDIA Developer sign-in that cannot fit the
        -- client's 15-second initialize window, so prime it once from
        -- a terminal with this same argv and complete the sign-in in
        -- the browser; later starts reuse the stored tokens. No
        -- credentials are stored here.
        name = 'nvidia-cuda-docs',
        command = '/usr/bin/npx',
        args = {
            '-y',
            'mcp-remote@0.14.3',
            'https://api.copilot.nsight.ngc.nvidia.com/mcp/cuda-docs',
        },
        enabled = true,
    },
    {
        name = 'phaedrus',
        command = '/home/phaedrus/.cargo/bin/phaedrus',
        args = {},
        enabled = true,
    },
    {
        -- Phlow (Matt's agent runtime, Rust port): `phlow serve`
        -- speaks newline-framed MCP over stdio. Hosts the MATE
        -- joint-attention board (the flow_attention_* tools) that
        -- ai.attention publishes through; the [attention] dispatch
        -- gate itself is configured in ~/.config/phlow/config.toml,
        -- not here. No credentials required.
        name = 'phlow',
        command = '/home/phaedrus/.local/bin/phlow',
        args = { 'serve' },
        enabled = true,
    },
    {
        -- Periscope (Matt's own broker, built 2026-10-11): brokers this
        -- config's LSP, formatter, linter, and DAP surface over MCP.
        -- Managed mode (no args): the broker spawns its own headless
        -- Neovim with this config, rooted at the client's working
        -- directory. Format and lint act on buffers only; nothing is
        -- written to disk. No credentials required.
        name = 'periscope',
        command = '/home/phaedrus/.local/bin/periscope',
        args = {},
        enabled = true,
    },
    {
        -- Seahawk (Matt's own broker, named 2026-10-27): born-modern
        -- rmcp broker for Unreal Engine 5.8's built-in MCP server --
        -- token auth, curated tool surface, execute-class default-deny
        -- via decide(), append-only op log. The sole argument is its
        -- config file, which also carries the acquisition lane's
        -- enablement and caps. No credentials required here.
        name = 'seahawk',
        command = '/home/phaedrus/.local/bin/seahawk',
        -- D-954 (2026-11-04): --profile full is pinned deliberately.
        -- This harness is the whole-surface agent route (Unreal GUI
        -- ladder = vision/gui, brokered downstream = broker,
        -- code.feedback = feedback, doujin acquisition = acquire);
        -- per-call harness policy + seahawk decide() still gate every
        -- call. A selector-less launch now serves core only.
        args = { '/home/phaedrus/.config/seahawk/seahawk.toml', '--profile', 'full' },
        enabled = true,
    },
    {
        name = 'slipway',
        command = '/home/phaedrus/.local/share/pax/mcpb-stage-1.0/slipway/slipway',
        args = { '--config', '/home/phaedrus/.local/share/pax/mcpb-stage-1.0/slipway/config.toml' },
        enabled = true,
    },
    {
        name = 'theodolite',
        command = '/home/phaedrus/.local/bin/theodolite',
        args = { '--config', '/home/phaedrus/.local/share/theodolite/bridge.toml' },
        enabled = true,
    },
    {
        name = 'vongola',
        command = '/home/phaedrus/.local/bin/vongola-mcp',
        args = {},
        enabled = true,
    },
}
