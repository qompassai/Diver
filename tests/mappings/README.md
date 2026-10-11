# tests/mappings/

Keymap/mapping definitions.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `mappings/run.lua` — Native APIs are real; external LSP/DAP services are controlled test doubles.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
mappings/run.lua
  └──▶ lua/mappings, lua/mappings/cicdmap, lua/mappings/ddxmap, lua/mappings/langmap (+1 more)
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:SfSoqlRun`
- `:SfSoslRun`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/mappings/run.lua
```

</details>
