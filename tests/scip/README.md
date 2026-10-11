# tests/scip/

SCIP code indexing.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `scip/scip_wiring.lua` — Self-test for the SCIP language wiring (scip.lang, scip.query,

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
scip/scip_wiring.lua
  └──▶ lua/ai/builder/scip, lua/ai/dataaccess/scip, lua/ai/retrieval/scip, lua/refactor/scip (+4 more)
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
nvim --headless -u NONE -i NONE -l tests/scip/scip_wiring.lua
```

</details>
