# tests/sf/

Salesforce tooling: trailhead, tasks.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `sf/salesforce_basename.lua` — Salesforce Code Analyzer basename-attribution test.
- `sf/salesforce_trailhead.lua` — Salesforce Trailhead async agent jobs test.
- `sf/sf_tasks.lua` — Tests for dev.sf.tasks -- the async Salesforce agent-task dispatcher.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
sf/salesforce_basename.lua
  └──▶ lua/linters/_salesforce-code-analyzer, lua/linters/code_analyzer
sf/salesforce_trailhead.lua
  └──▶ lua/dev/sf, lua/dev/sf/trailhead, lua/utils
sf/sf_tasks.lua
  └──▶ lua/dev/sf/tasks
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:SfTrailheadAddStep`
- `:SfTrailheadEnqueue`
- `:SfTrailheadStart`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/sf/salesforce_basename.lua
nvim --headless -u NONE -i NONE -l tests/sf/salesforce_trailhead.lua
nvim --headless -u NONE -i NONE -l tests/sf/sf_tasks.lua
```

</details>
