# tests/busted/

Busted unit/integration specs (busted framework).

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `busted/helpers/init.lua` — tests/busted/helpers/init.lua
- `busted/integration/adapters_native_spec.lua` — tests/busted/integration/adapters_native_spec.lua
- `busted/integration/harness_run_spec.lua` — tests/busted/integration/harness_run_spec.lua
- `busted/unit/adapter_spec.lua` — tests/busted/unit/adapter_spec.lua
- `busted/unit/approval_spec.lua` — tests/busted/unit/approval_spec.lua
- `busted/unit/budget_spec.lua` — tests/busted/unit/budget_spec.lua
- `busted/unit/context_spec.lua` — tests/busted/unit/context_spec.lua
- `busted/unit/dispatch_spec.lua` — tests/busted/unit/dispatch_spec.lua
- `busted/unit/events_spec.lua` — tests/busted/unit/events_spec.lua
- `busted/unit/health_spec.lua` — tests/busted/unit/health_spec.lua
- `busted/unit/init_spec.lua` — tests/busted/unit/init_spec.lua
- `busted/unit/mcp_declared_spec.lua` — tests/busted/unit/mcp_declared_spec.lua
- `busted/unit/mcp_secrets_spec.lua` — tests/busted/unit/mcp_secrets_spec.lua
- `busted/unit/policy_spec.lua` — tests/busted/unit/policy_spec.lua
- `busted/unit/registry_spec.lua` — tests/busted/unit/registry_spec.lua
- `busted/unit/sandbox_spec.lua` — tests/busted/unit/sandbox_spec.lua
- `busted/unit/store_spec.lua` — tests/busted/unit/store_spec.lua
- `busted/unit/supervisor_spec.lua` — tests/busted/unit/supervisor_spec.lua
- `busted/unit/telemetry_spec.lua` — tests/busted/unit/telemetry_spec.lua
- `busted/unit/types_spec.lua` — tests/busted/unit/types_spec.lua
- `busted/unit/verdict_spec.lua` — tests/busted/unit/verdict_spec.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
busted/helpers/init.lua
  └──▶ (self-contained)
busted/integration/adapters_native_spec.lua
  └──▶ lua/ai/harness/adapters/, lua/ai/harness/types
busted/integration/harness_run_spec.lua
  └──▶ lua/ai/harness, lua/ai/harness/events, lua/ai/harness/registry, lua/ai/harness/supervisor (+1 more)
busted/unit/adapter_spec.lua
  └──▶ lua/ai/harness/adapter, lua/ai/harness/types
busted/unit/approval_spec.lua
  └──▶ lua/ai/harness/approval, lua/ai/harness/types
busted/unit/budget_spec.lua
  └──▶ lua/ai/harness/budget
busted/unit/context_spec.lua
  └──▶ lua/ai/harness/context
busted/unit/dispatch_spec.lua
  └──▶ lua/ai/harness, lua/ai/harness/policy, lua/ai/harness/registry, lua/ai/harness/supervisor
busted/unit/events_spec.lua
  └──▶ lua/ai/harness/events, lua/ai/harness/types
busted/unit/health_spec.lua
  └──▶ lua/ai/harness/health, lua/ai/harness/registry, lua/ai/harness/store
busted/unit/init_spec.lua
  └──▶ lua/ai/harness, lua/ai/harness/registry, lua/ai/harness/supervisor
busted/unit/mcp_declared_spec.lua
  └──▶ lua/ai/mcp/declared
busted/unit/mcp_secrets_spec.lua
  └──▶ lua/ai/mcp/secrets
busted/unit/policy_spec.lua
  └──▶ lua/ai/harness/policy
busted/unit/registry_spec.lua
  └──▶ lua/ai/harness/registry
busted/unit/sandbox_spec.lua
  └──▶ lua/ai/harness/sandbox
busted/unit/store_spec.lua
  └──▶ lua/ai/harness/store
busted/unit/supervisor_spec.lua
  └──▶ lua/ai/harness/events, lua/ai/harness/registry, lua/ai/harness/supervisor, lua/ai/harness/types
busted/unit/telemetry_spec.lua
  └──▶ lua/ai/harness/telemetry
busted/unit/types_spec.lua
  └──▶ lua/ai/harness/types
busted/unit/verdict_spec.lua
  └──▶ lua/ai/harness/verdict
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

(no commands or keymaps asserted in these tests)

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/busted/helpers/init.lua
nvim --headless -u NONE -i NONE -l tests/busted/integration/adapters_native_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/integration/harness_run_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/adapter_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/approval_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/budget_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/context_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/events_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/health_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/init_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/mcp_declared_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/mcp_secrets_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/policy_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/registry_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/sandbox_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/store_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/supervisor_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/telemetry_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/types_spec.lua
nvim --headless -u NONE -i NONE -l tests/busted/unit/verdict_spec.lua
```

</details>
