# tests/security/

Security: guard, masking, PQC, ownership.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `security/guard.lua` — Qompass AI Diver sensitive-file guard tests
- `security/mask.lua` — Qompass AI Diver secret-masking tests
- `security/ownership_guard_adversarial.lua` — tests/security/ownership_guard_adversarial.lua
- `security/pass.lua` — tests/security/pass.lua
- `security/pqc_adversarial.lua` — pqc_adversarial.lua — try to break the token/PQC/bridge code.
- `security/pqc_token.lua` — PQC + capability-token self-test: keygen, signatures, KEM, tokens,

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
security/guard.lua
  └──▶ lua/security/guard
security/mask.lua
  └──▶ lua/security/mask
security/ownership_guard_adversarial.lua
  └──▶ lua/formatters
security/pass.lua
  └──▶ lua/pass
security/pqc_adversarial.lua
  └──▶ lua/ai/security/pqc, lua/ai/security/token, lua/ai/webmcp/bridge, lua/websocket/client
security/pqc_token.lua
  └──▶ lua/ai/security/pqc, lua/ai/security/token, lua/ai/webmcp/bridge, lua/websocket/client
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:GuardToggle`
- `:MaskToggle`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/security/guard.lua
nvim --headless -u NONE -i NONE -l tests/security/mask.lua
nvim --headless -u init.lua -c "luafile tests/security/ownership_guard_adversarial.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/security/pass.lua" -c "qall!"
nvim --headless -u NONE -i NONE -l tests/security/pqc_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/security/pqc_token.lua
```

</details>
