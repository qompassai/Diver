# tests/markdown/

Markdown rendering.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `markdown/markdown_render.lua` — Native Markdown renderer functional test.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
markdown/markdown_render.lua
  └──▶ lua/config/markdown/render
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
nvim --headless -u NONE -i NONE -l tests/markdown/markdown_render.lua
```

</details>
