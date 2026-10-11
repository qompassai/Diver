# tests/mcp/

Model Context Protocol server.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `mcp/mcp_server/common.lua` — Shared test harness for the MCP server specs.
- `mcp/mcp_server/json.lua` — Minimal JSON codec for the MCP server test harness.
- `mcp/mcp_server/policy_adversarial.lua` — Adversarial spec: policy scoping and command validation.
- `mcp/mcp_server/policy_spec.lua` — Validation spec: MCP server fail-closed policy.
- `mcp/mcp_server/protocol_adversarial.lua` — Adversarial spec: MCP server protocol engine.
- `mcp/mcp_server/protocol_spec.lua` — Validation spec: MCP server protocol engine (dispatch, handshake, errors).
- `mcp/mcp_server/stdio_adversarial.lua` — Adversarial spec: stdio transport abuse.
- `mcp/mcp_server/stdio_spec.lua` — Validation spec: stdio transport + full-stack dogfood.
- `mcp/mcp_server/tools_adversarial.lua` — Adversarial spec: tool registry, path scoping, write tools, run_command.
- `mcp/mcp_server/tools_spec.lua` — Validation spec: MCP tool registry + read tools + get_diagnostics.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
mcp/mcp_server/common.lua
  └──▶ (self-contained)
mcp/mcp_server/json.lua
  └──▶ (self-contained)
mcp/mcp_server/policy_adversarial.lua
  └──▶ lua/ai/mcp/server/policy
mcp/mcp_server/policy_spec.lua
  └──▶ lua/ai/mcp/server/policy
mcp/mcp_server/protocol_adversarial.lua
  └──▶ lua/ai/mcp/server/protocol
mcp/mcp_server/protocol_spec.lua
  └──▶ lua/ai/mcp/server/protocol
mcp/mcp_server/stdio_adversarial.lua
  └──▶ lua/ai/mcp/server/protocol, lua/ai/mcp/server/stdio
mcp/mcp_server/stdio_spec.lua
  └──▶ lua/ai/mcp/server/policy, lua/ai/mcp/server/protocol, lua/ai/mcp/server/stdio, lua/ai/mcp/server/tools
mcp/mcp_server/tools_adversarial.lua
  └──▶ lua/ai/mcp/server/policy, lua/ai/mcp/server/tools
mcp/mcp_server/tools_spec.lua
  └──▶ lua/ai/mcp/server/policy, lua/ai/mcp/server/tools
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:ECHO`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/common.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/json.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/policy_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/policy_spec.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/protocol_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/protocol_spec.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/stdio_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/stdio_spec.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/tools_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/mcp/mcp_server/tools_spec.lua
```

</details>
