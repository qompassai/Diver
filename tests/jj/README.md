# tests/jj/

Jujutsu (jj) VCS integration.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `jj/jj.lua` — Balanced suite for the jj module: exactly half adversarial and half

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
jj/jj.lua
  └──▶ lua/jj
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
nvim --headless -u init.lua -c "luafile tests/jj/jj.lua" -c "qall!"
```

</details>
