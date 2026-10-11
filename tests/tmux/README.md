# tests/tmux/

Tmux integration.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `tmux/tmux.lua` — tests/tmux/tmux.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
tmux/tmux.lua
  └──▶ lua/tmux, lua/utils/toolmgr
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Keymaps covered:

- `<C-h>`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/tmux/tmux.lua" -c "qall!"
```

</details>
