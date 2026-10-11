# tests/tools/

General tools (notify).

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `tools/notify.lua` — tests/tools/notify.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
tools/notify.lua
  └──▶ lua/tools/notify
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
nvim --headless -u init.lua -c "luafile tests/tools/notify.lua" -c "qall!"
```

</details>
