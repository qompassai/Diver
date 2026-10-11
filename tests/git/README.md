# tests/git/

Git integration (dev.git).

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `git/git.lua` — tests/git/git.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
git/git.lua
  └──▶ lua/git, lua/git/xet
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:GitXetStatus`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/git/git.lua" -c "qall!"
```

</details>
