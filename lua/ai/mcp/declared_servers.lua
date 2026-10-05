-- /qompassai/Diver/lua/ai/mcp/declared_servers.lua
-- Qompass AI Declared MCP Servers (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
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
        name = 'git',
        command = '/usr/bin/uvx',
        args = { 'mcp-server-git' },
        enabled = true,
    },
    {
        name = 'fetch',
        command = '/usr/bin/uvx',
        args = { 'mcp-server-fetch' },
        enabled = true,
    },
    {
        -- Docker-based; stays off until the token exists in pass and docker
        -- is wanted on the machine. Enable by flipping enabled to true.
        name = 'github',
        command = '/usr/bin/docker',
        args = {
            'run',
            '-i',
            '--rm',
            '-e',
            'GITHUB_PERSONAL_ACCESS_TOKEN',
            'ghcr.io/github/github-mcp-server',
        },
        secrets = {
            GITHUB_PERSONAL_ACCESS_TOKEN = { provider = 'pass', path = 'github/mcp-token' },
        },
        enabled = false,
    },
}
