# tests/dev/

Developer tooling: apps, cargo, run, scip.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `dev/cargo.lua` — tests/dev/cargo.lua
- `dev/dev_apps.lua` — tests/dev/dev_apps.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
dev/cargo.lua
  └──▶ lua/dev/cargo
dev/dev_apps.lua
  └──▶ lua/dev/apps
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:Cargo`
- `:CargoDocs`
- `:CargoUpdateCheck`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/dev/cargo.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/dev/dev_apps.lua" -c "qall!"
```

</details>
