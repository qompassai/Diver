# tests/bsp/

Build Server Protocol registry and fixtures.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `bsp/bsp_registry.lua` — Headless BSP registry + detection test (validation + adversarial).

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
bsp/bsp_registry.lua
  └──▶ lua/ai/debugbridge/bsp, lua/bsp, lua/bsp/servers, lua/bsp/servers/gradle (+4 more)
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:BspCompile`
- `:BspReload`
- `:BspRestart`
- `:BspStart`
- `:BspStop`
- `:BspTargets`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/bsp/bsp_registry.lua
```

</details>
