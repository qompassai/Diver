# tests/research/

Research tooling: doc headers.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `research/research_docs_make_header.lua` — Tests for research.docs.make_header -- the function 19 lang-config

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
research/research_docs_make_header.lua
  └──▶ lua/research/docs
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
nvim --headless -u NONE -i NONE -l tests/research/research_docs_make_header.lua
```

</details>
