# tests/research/

Research tooling test suites.

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
- `research/research_journal_workflow.lua` — Tests for the research journal workflow: journal requirements profiles, per-journal templates, submission preflight, Zenodo token handling, and the JSON registry export
- `research/research_zotero_api.lua` — Tests for research.zotero_api (candidate matching, item/BibTeX construction, filing via a stubbed transport) and the arXiv DOI capture in research.discover.parse_feed

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
research/research_docs_make_header.lua
  └──▶ lua/research/docs

research/research_journal_workflow.lua
  ├──▶ lua/research/journal
  ├──▶ lua/research/manuscript
  ├──▶ lua/research/submission
  ├──▶ lua/research/templates
  ├──▶ lua/research/wos
  ├──▶ lua/research/zenodo
  ├──▶ lua/research/deadlines
  ├──▶ lua/research/openalex
  └──▶ lua/research/watchlist

research/research_zotero_api.lua
  ├──▶ lua/research/zotero_api
  └──▶ lua/research/discover (parse_feed DOI capture)
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
nvim --headless -u NONE -i NONE -l tests/research/research_journal_workflow.lua
nvim --headless -u NONE -i NONE -l tests/research/research_zotero_api.lua
```

</details>
