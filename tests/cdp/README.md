# tests/cdp/

Chrome DevTools Protocol implementation.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `cdp/cdp/json.lua` — tests/cdp/cdp/json.lua
- `cdp/cdp/run.lua` — tests/cdp/cdp/run.lua
- `cdp/cdp/t.lua` — tests/cdp/cdp/t.lua
- `cdp/cdp/test_actions.lua` — tests/cdp/cdp/test_actions.lua
- `cdp/cdp/test_commands.lua` — tests/cdp/cdp/test_commands.lua
- `cdp/cdp/test_domains.lua` — tests/cdp/cdp/test_domains.lua
- `cdp/cdp/test_init.lua` — tests/cdp/cdp/test_init.lua
- `cdp/cdp/test_security.lua` — tests/cdp/cdp/test_security.lua
- `cdp/cdp/test_session.lua` — tests/cdp/cdp/test_session.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
cdp/cdp/json.lua
  └──▶ (self-contained)
cdp/cdp/run.lua
  └──▶ lua/cdp/vim_stub
cdp/cdp/t.lua
  └──▶ (self-contained)
cdp/cdp/test_actions.lua
  └──▶ lua/cdp/fixture, lua/cdp/t, lua/dev/browser/cdp, lua/dev/browser/cdp/actions
cdp/cdp/test_commands.lua
  └──▶ lua/cdp/fixture, lua/cdp/t, lua/dev/browser/cdp, lua/dev/browser/cdp/commands
cdp/cdp/test_domains.lua
  └──▶ lua/cdp/t, lua/dev/browser/cdp/domains
cdp/cdp/test_init.lua
  └──▶ lua/cdp/fixture, lua/cdp/t, lua/dev/browser/cdp, lua/dev/browser/cdp/domains
cdp/cdp/test_security.lua
  └──▶ lua/cdp/t, lua/dev/browser/cdp/security
cdp/cdp/test_session.lua
  └──▶ lua/cdp/json, lua/cdp/t, lua/dev/browser/cdp/session
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:BrowserConsole`
- `:BrowserEval`
- `:BrowserNavigate`
- `:BrowserOpen`
- `:CdpConsoleMessage`
- `:CdpPaused`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/json.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/run.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/t.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_actions.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_commands.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_domains.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_init.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_security.lua
nvim --headless -u NONE -i NONE -l tests/cdp/cdp/test_session.lua
```

</details>
