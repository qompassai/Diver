# tests/nav/

Navigation: finders and the directory ring.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `nav/core_nav.lua` — Navigation self-test — proves the nav helpers work.
- `nav/dirring.lua` — Qompass AI Diver directory-ring tests
- `nav/nav.lua` — tests/nav/nav.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
nav/core_nav.lua
  └──▶ lua/config/core/async, lua/config/core/filetype, lua/config/core/parser, lua/config/core/qf (+6 more)
nav/dirring.lua
  └──▶ lua/config/nav, lua/config/nav/dirring, lua/utils/nav
nav/nav.lua
  └──▶ lua/config/nav/dirring
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:ConfigSelfCheck`
- `:DirList`
- `:DirNext`
- `:DirPrev`
- `:DirPush`
- `:DirReset`
- `:NavUpdateCheck`

Keymaps covered:

- `,dr`
- `,nd`
- `<leader>hs`
- `<leader>ng`
- `<leader>qf`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/nav/core_nav.lua
nvim --headless -u NONE -i NONE -l tests/nav/dirring.lua
nvim --headless -u init.lua -c "luafile tests/nav/nav.lua" -c "qall!"
```

</details>
