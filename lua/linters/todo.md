
<!-- Source: https://github.com/mcandre/linters -->

# nvim-lint Linters

## Status Legend

| State | Meaning |
| --- | --- |
| `DONE` | A matching local linter configuration exists |
| `TODO` | No matching local linter configuration was found |

## Progress

| Inventory | Done | Remaining | Total |
| --- | ---: | ---: | ---: |
| nvim-lint | 57 | 129 | 186 |
| MegaLinter | 8 | 48 | 56 |
| **Combined upstream inventory** | **65** | **177** | **242** |
| Additional local configurations | 27 | 0 | 27 |

**Local linter configuration modules:** 90

| Linter | Last updated | State | Local config |
| --- | ---: | :---: | --- |
| [`actionlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/actionlint.lua) | 2025-12-13 | `DONE` | [`actionlint.lua`](./actionlint.lua) |
| [`alex`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/alex.lua) | 2023-10-18 | `DONE` | [`alex.lua`](./alex.lua) |
| [`ameba`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ameba.lua) | 2026-05-19 | `DONE` | [`ameba.lua`](./ameba.lua) |
| [`ansible_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ansible_lint.lua) | 2025-08-21 | `DONE` | [`ansible_lint.lua`](./ansible_lint.lua) |
| [`bandit`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/bandit.lua) | 2023-01-15 | `DONE` | [`bandit.lua`](./bandit.lua) |
| [`bash`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/bash.lua) | 2024-09-20 | `DONE` | [`bash.lua`](./bash.lua) |
| [`bean_check`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/bean_check.lua) | 2023-01-29 | `DONE' | — |
| [`biomejs`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/biomejs.lua) | 2024-01-15 | `DONE` | [`biome.lua`](./biome.lua) |
| [`blocklint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/blocklint.lua) | 2023-10-18 | `TOREMOVE` | 'Overlap with Alex' |
| [`buf_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/buf_lint.lua) | 2023-04-02 | `DONE` | [`buf_lint.lua`](./buf_lint.lua) |
| [`buildifier`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/buildifier.lua) | 2023-08-03 | `DONE` | [`buildifier.lua`](./buildifier.lua) |
| [`cfn_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cfn_lint.lua) | 2025-05-22 | `TODO` | — |
| [`cfn_nag`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cfn_nag.lua) | 2022-11-29 | `TODO` | — |
| [`checkbashisms`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/checkbashisms.lua) | 2026-04-09 | `DONE` | [`checkbashisms.lua`](./checkbashisms.lua) |
| [`checkmake`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/checkmake.lua) | 2024-02-06 | `DONE` | [`checkmake.lua`](./checkmake.lua) |
| [`checkpatch`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/checkpatch.lua) | 2025-12-11 | `DONE` | [`checkpatch.lua`](./checkpatch.lua) |
| [`checkstyle`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/checkstyle.lua) | 2025-06-05 | `TODO` | [`checkstyle.lua`](./checkstyle.lua) |
| [`chktex`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/chktex.lua) | 2022-03-07 | `DONE` | [`chktex.lua`](./chktex.lua) |
| [`clangtidy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/clangtidy.lua) | 2026-05-19 | `DONE` | [`clangtidy.lua`](./clangtidy.lua) |
| [`clazy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/clazy.lua) | 2021-12-11 | `DONE` | [`clazy.lua`](./clazy.lua) |
| [`clippy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/clippy.lua) | 2024-08-08 | `DONE` | [`clippy.lua`](./clippy.lua) |
| [`clj-kondo`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/clj-kondo.lua) | 2024-12-19 | `DONE` | [`clj-kondo.lua`](./clj-kondo.lua) |
| [`cmake_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cmake_lint.lua) | 2025-11-16 | `DONE` | [`cmake-lint.lua`](./cmake-lint.lua) |
| [`cmakelint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cmakelint.lua) | 2023-10-24 | `TOREMOVE` | — |
| [`codespell`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/codespell.lua) | 2024-08-16 | `TODO` | — |
| [`commitlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/commitlint.lua) | 2023-10-20 | `DONE` | [`commitlint.lua`](./commitlint.lua) |
| [`compiler`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/compiler.lua) | 2025-12-23 | `TODO` | — |
| [`cppcheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cppcheck.lua) | 2024-05-13 | `DONE` | [`cppcheck.lua`](./cppcheck.lua) |
| [`cpplint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cpplint.lua) | 2023-11-29 | `TODO` | — |
| [`credo`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/credo.lua) | 2026-06-06 | `DONE` | [`credo.lua`](./credo.lua) |
| [`cspell`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cspell.lua) | 2025-12-19 | `TODO` | — |
| [`cue`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/cue.lua) | 2024-02-20 | `TODO` | — |
| [`curlylint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/curlylint.lua) | 2023-01-18 | `TODO` | — |
| [`dash`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dash.lua) | 2023-12-27 | `TODO` | — |
| [`dclint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dclint.lua) | 2025-10-07 | `TODO` | — |
| [`deadnix`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/deadnix.lua) | 2024-04-05 | `DONE` | [`deadnix.lua`](./deadnix.lua) |
| [`deno`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/deno.lua) | 2023-10-06 | `TODO` | — |
| [`detect-secrets`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/detect-secrets.lua) | 2026-04-09 | `DONE` | [`detect-secrets.lua`](./detect-secrets.lua) |
| [`detekt`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/detekt.lua) | 2026-06-19 | `DONE` |[`detekt.lua`](./detekt.lua) |
| [`dialyxir`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dialyxir.lua) | 2026-05-13 | `TODO` | — |
| [`djlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/djlint.lua) | 2023-07-30 | `DONE` | [`djlint.lua`](./djlint.lua) |
| [`dmypy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dmypy.lua) | 2024-12-19 | `TODO` | — |
| [`dotenv_linter`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dotenv_linter.lua) | 2025-11-01 | `DONE` | [`dotenv-linter.lua`](./dotenv-linter.lua) |
| [`dxc`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dxc.lua) | 2022-06-18 | `TODO` | — |
| [`editorconfig-checker`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/editorconfig-checker.lua) | 2023-09-30 | `DONE` | [`editorconfig-checker.lua`](./editorconfig-checker.lua) |
| [`erb_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/erb_lint.lua) | 2023-06-11 | `TODO` | — |
| [`eslint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/eslint.lua) | 2024-06-26 | `TODO` | — |
| [`eslint_d`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/eslint_d.lua) | 2025-11-01 | `DONE` | [`eslint_d.lua`](./eslint_d.lua) |
| [`eugene`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/eugene.lua) | 2024-08-08 | `TODO` | — |
| [`fennel`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/fennel.lua) | 2022-04-24 | `TODO` | — |
| [`fieldalignment`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/fieldalignment.lua) | 2025-09-14 | `DONE` | [`fieldalignment.lua`](./fieldalignment.lua) |
| [`fish`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/fish.lua) | 2025-01-05 | `TODO` | — |
| [`flake8`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/flake8.lua) | 2023-12-27 | `TODO` | — |
| [`flawfinder`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/flawfinder.lua) | 2021-12-11 | `TODO` | — |
| [`fortitude`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/fortitude.lua) | 2025-04-19 | `TODO` | — |
| [`fsharplint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/fsharplint.lua) | 2025-07-20 | `TODO` | — |
| [`gawk`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/gawk.lua) | 2024-10-17 | `TODO` | — |
| [`gdlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/gdlint.lua) | 2025-05-13 | `TODO` | — |
| [`ghdl`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ghdl.lua) | 2025-01-06 | `TODO` | — |
| [`gitleaks`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/gitleaks.lua) | 2026-01-05 | `TODO` | — |
| [`gitlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/gitlint.lua) | 2025-09-14 | `TODO` | — |
| [`glslc`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/glslc.lua) | 2022-05-01 | `TODO` | — |
| [`golangcilint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/golangcilint.lua) | 2025-12-17 | `DONE` | [`golangcilint.lua`](./golangcilint.lua) |
| [`hadolint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/hadolint.lua) | 2023-10-18 | `DONE` | [`hadolint.lua`](./hadolint.lua) |
| [`herb`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/herb.lua) | 2026-05-13 | `TODO` | — |
| [`hledger`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/hledger.lua) | 2024-08-16 | `TODO` | — |
| [`hlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/hlint.lua) | 2024-12-19 | `DONE` | [`hlint.lua`](./hlint.lua) |
| [`htmlhint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/htmlhint.lua) | 2024-02-22 | `DONE` | [`htmlhint.lua`](./htmlhint.lua) |
| [`inko`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/inko.lua) | 2022-01-20 | `TODO` | — |
| [`janet`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/janet.lua) | 2026-06-17 | `DONE` | [`janet.lua`](./janet.lua) |
| [`joker`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/joker.lua) | 2023-12-08 | `DONE` | [`joker.lua`](./joker.lua) |
| [`jq`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/jq.lua) | 2025-01-18 | `TODO` | — |
| [`jshint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/jshint.lua) | 2021-12-11 | `TODO` | — |
| [`json5`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/json5.lua) | 2025-06-04 | `TODO` | — |
| [`json_tool`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/json_tool.lua) | 2025-11-19 | `TODO` | — |
| [`jsonlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/jsonlint.lua) | 2023-10-11 | `TODO` | — |
| [`ksh`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ksh.lua) | 2024-09-20 | `TODO` | — |
| [`ktlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ktlint.lua) | 2024-02-01 | `DONE` | [`ktlint.lua`](./ktlint.lua) |
| [`lacheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/lacheck.lua) | 2022-03-09 | `DONE` | [`lacheck.lua`](./lacheck.lua) |
| [`languagetool`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/languagetool.lua) | 2023-10-12 | `TODO` | — |
| [`lint-openapi`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/lint-openapi.lua) | 2025-12-06 | `DONE` | [`lint-openapi.lua`](./lint-openapi.lua) |
| [`ls_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ls_lint.lua) | 2025-11-15 | `TODO` | — |
| [`lslint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/lslint.lua) | 2025-07-20 | `TODO` | — |
| [`luac`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/luac.lua) | 2024-09-20 | `DONE` | [`luac.lua`](./luac.lua) |
| [`luacheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/luacheck.lua) | 2022-10-16 | `DONE` | [`luacheck.lua`](./luacheck.lua) |
| [`mado`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mado.lua) | 2025-11-21 | `DONE` | [`mado.lua`](./mado.lua) |
| [`mago_analyze`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mago_analyze.lua) | 2025-11-19 | `DONE` |[`mago_analyze.lua`](./mago_analyze.lua) |
| [`mago_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mago_lint.lua) | 2025-11-19 | `TODO` | — |
| [`markdownlint-cli2`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/markdownlint-cli2.lua) | 2026-01-07 | `TODO` | — |
| [`markdownlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/markdownlint.lua) | 2024-09-22 | `DONE` | [`markdownlint.lua`](./markdownlint.lua) |
| [`markuplint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/markuplint.lua) | 2024-02-24 | `TODO` | — |
| [`mbake`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mbake.lua) | 2026-03-26 | `DONE` | [`mbake.lua`](./mbake.lua) |
| [`mh_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mh_lint.lua) | 2025-12-04 | `TODO` | — |
| [`mlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mlint.lua) | 2021-12-11 | `TODO` | — |
| [`mypy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/mypy.lua) | 2025-03-17 | `TODO` | — |
| [`nagelfar`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/nagelfar.lua) | 2022-10-25 | `TODO` | — |
| [`nix`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/nix.lua) | 2021-12-11 | `DONE` | [`nix.lua`](./nix.lua) |
| [`npm-groovy-lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/npm-groovy-lint.lua) | 2026-01-28 | `TODO` | — |
| [`oelint-adv`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/oelint-adv.lua) | 2026-06-25 | `TODO` | — |
| [`opa_check`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/opa_check.lua) | 2024-01-18 | `TODO` | — |
| [`oxlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/oxlint.lua) | 2025-08-28 | `DONE` | [`oxlint.lua`](./oxlint.lua) |
| [`panache`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/panache.lua) | 2026-05-13 | `DONE` | panache.lua |
| [`perlcritic`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/perlcritic.lua) | 2024-02-29 | `TODO` | — |
| [`perlimports`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/perlimports.lua) | 2023-08-21 | `TODO` | — |
| [`pflake8`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pflake8.lua) | 2023-11-09 | `TODO` | — |
| [`php`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/php.lua) | 2023-07-13 | `TODO` | — |
| [`phpcs`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/phpcs.lua) | 2025-05-22 | `TODO` | — |
| [`phpinsights`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/phpinsights.lua) | 2024-09-14 | `TODO` | — |
| [`phpmd`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/phpmd.lua) | 2024-03-20 | `TODO` | — |
| [`phpstan`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/phpstan.lua) | 2025-04-05 | `TODO` | — |
| [`pmd`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pmd.lua) | 2025-06-05 | `TODO` | — |
| [`pony`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pony.lua) | 2024-01-07 | `TODO` | — |
| [`prisma-lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/prisma-lint.lua) | 2023-12-05 | `TODO` | — |
| [`proselint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/proselint.lua) | 2026-01-07 | `DONE` | [`proselint.lua`](./proselint.lua) |
| [`protolint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/protolint.lua) | 2024-10-31 | `TODO` | — |
| [`psalm`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/psalm.lua) | 2024-01-02 | `TODO` | — |
| [`puppet-lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/puppet-lint.lua) | 2023-11-08 | `DONE` | [`puppet-lint.lua`](./puppet-lint.lua) |
| [`pycodestyle`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pycodestyle.lua) | 2021-12-11 | `TODO` | — |
| [`pydocstyle`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pydocstyle.lua) | 2021-12-01 | `TODO` | — |
| [`pylint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pylint.lua) | 2024-08-08 | `TODO` | — |
| [`pyrefly`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/pyrefly.lua) | 2025-12-04 | `DONE` | [`pyrefly.lua`](./pyrefly.lua) |
| [`quick-lint-js`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/quick-lint-js.lua) | 2024-01-18 | `TODO` | — |
| [`redocly`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/redocly.lua) | 2025-04-15 | `TODO` | — |
| [`regal`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/regal.lua) | 2024-01-18 | `DONE` | [`regal.lua`](./regal.lua) |
| [`revive`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/revive.lua) | 2024-09-12 | `DONE` | [`revive.lua`](./revive.lua) |
| [`rflint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rflint.lua) | 2021-11-24 | `Not Maintained` | — |
| [`robocop`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/robocop.lua) | 2021-11-25 | `TODO` | — |
| [`rpmlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rpmlint.lua) | 2024-12-19 | `TODO` | — |
| [`rpmspec`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rpmspec.lua) | 2025-09-24 | `TODO` | — |
| [`rstcheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rstcheck.lua) | 2021-12-30 | `DONE` | [`rstcheck.lua`](./rstcheck.lua) |
| [`rst-lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rstlint.lua) | 2021-12-30 | `DONE` | [`rst-lint.lua`](./rst-lint.lua) |
| [`rubocop`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rubocop.lua) | 2024-02-20 | `TODO` | — |
| [`ruby`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ruby.lua) | 2022-05-02 | `TODO` | — |
| [`ruff`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ruff.lua) | 2025-07-04 | `TODO` | — |
| [`rumdl`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/rumdl.lua) | 2025-11-13 | `DONE` | [`rumdl.lua`](./rumdl.lua) |
| [`saltlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/saltlint.lua) | 2024-01-15 | `TODO` | — |
| [`selene`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/selene.lua) | 2023-09-21 | `TODO` | — |
| [`shellcheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/shellcheck.lua) | 2025-06-05 | `DONE` | [`shellcheck.lua`](./shellcheck.lua) |
| [`slang`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/slang.lua) | 2024-10-02 | `TODO` | — |
| [`snakemake`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/snakemake.lua) | 2024-09-22 | `TODO` | — |
| [`snyk_iac`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/snyk_iac.lua) | 2023-10-20 | `TODO` | — |
| [`solhint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/solhint.lua) | 2023-08-19 | `TODO` | — |
| [`spectral`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/spectral.lua) | 2026-01-31 | `TODO` | — |
| [`sphinx-lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/sphinx-lint.lua) | 2024-11-18 | `DONE` | [`sphinx-lint.lua`](./sphinx-lint.lua) |
| [`sqlfluff`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/sqlfluff.lua) | 2026-01-05 | `TODO` | — |
| [`sqruff`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/sqruff.lua) | 2025-01-21 | `TODO` | — |
| [`squawk`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/squawk.lua) | 2025-12-04 | `TODO` | — |
| [`standardjs`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/standardjs.lua) | 2024-12-19 | `TODO` | — |
| [`standardrb`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/standardrb.lua) | 2022-03-07 | `TODO` | — |
| [`staticcheck`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/staticcheck.lua) | 2023-07-20 | `TODO` | — |
| [`statix`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/statix.lua) | 2023-12-28 | `DONE` | [`statix.lua`](./statix.lua) |
| [`stylelint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/stylelint.lua) | 2025-08-28 | `DONE` | [`stylelint.lua`](./stylelint.lua) |
| [`svlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/svlint.lua) | 2024-10-03 | `TODO` | — |
| [`swiftlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/swiftlint.lua) | 2024-03-14 | `TODO` | — |
| [`systemd-analyze`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/systemd-analyze.lua) | 2024-08-16 | `DONE` | [`systemd-analyze.lua`](./systemd-analyze.lua) |
| [`systemdlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/systemdlint.lua) | 2024-02-20 | `TODO` | — |
| [`tclint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tclint.lua) | 2025-11-19 | `TODO` | — |
| [`terraform_validate`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/terraform_validate.lua) | 2026-02-16 | `TODO` | — |
| [`tflint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tflint.lua) | 2025-04-03 | `DONE` | [`tflint.lua`](./tflint.lua) |
| [`tfsec`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tfsec.lua) | 2023-07-26 | `TODO` | — |
| [`tidy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tidy.lua) | 2024-08-16 | `TODO` | — |
| [`tlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tlint.lua) | 2023-11-29 | `TODO` | — |
| [`tofu`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tofu.lua) | 2026-02-16 | `TODO` | — |
| [`tombi`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/tombi.lua) | 2025-11-06 | `TODO` | — |
| [`trivy`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/trivy.lua) | 2024-05-31 | `TODO` | — |
| [`trivy_secret`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/trivy_secret.lua) | 2026-06-20 | `TODO` | — |
| [`ts-standard`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/ts-standard.lua) | 2025-01-18 | `TODO` | — |
| [`twig-cs-fixer`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/twig-cs-fixer.lua) | 2025-03-26 | `TODO` | — |
| [`twigcs`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/twigcs.lua) | 2023-09-07 | `TODO` | — |
| [`typos`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/typos.lua) | 2025-10-07 | `TODO` | — |
| [`unmake`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/unmake.lua) | 2026-06-17 | `TODO` | — |
| [`vacuum`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vacuum.lua) | 2025-12-06 | `TODO` | — |
| [`vala_lint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vala_lint.lua) | 2024-01-20 | `TODO` | — |
| [`vale`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vale.lua) | 2023-09-19 | `TODO` | — |
| [`verilator`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/verilator.lua) | 2024-10-03 | `TODO` | — |
| [`vint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vint.lua) | 2022-01-20 | `DONE` | [`vint.lua`](./vint.lua) |
| [`vsg`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vsg.lua) | 2024-06-26 | `TODO` | — |
| [`vulture`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/vulture.lua) | 2022-01-05 | `DONE` | [`vulture.lua`](./vulture.lua) |
| [`woke`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/woke.lua) | 2023-10-18 | `TODO` | — |
| [`write_good`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/write_good.lua) | 2023-10-19 | `TODO` | — |
| [`yamllint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/yamllint.lua) | 2023-05-29 | `DONE` | [`yamllint.lua`](./yamllint.lua) |
| [`yq`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/yq.lua) | 2024-09-14 | `TODO` | — |
| [`zig`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/zig.lua) | 2022-01-24 | `TODO` | — |
| [`zizmor`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/zizmor.lua) | 2026-05-18 | `TODO` | — |
| [`zlint`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/zlint.lua) | 2025-09-24 | `DONE` | [`zlint.lua`](./zlint.lua) |
| [`zsh`](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/zsh.lua) | 2025-05-13 | `TODO` | — |

---

## MegaLinter Linters

| Linter / Tool | Repository | Latest commit | State | Local config |
| --- | --- | ---: | :---: | --- |
| `arm-ttk` | [Azure/arm-ttk](https://github.com/Azure/arm-ttk) | 2024-03-27 | `TODO` | — |
| `bash-exec` | [tianon/mirror-bash](https://github.com/tianon/mirror-bash) | 2025-07-23 | `TODO` | — |
| `bicep_linter` | [Azure/bicep](https://github.com/Azure/bicep) | 2026-08-06 | `TODO` | — |
| `black` | [psf/black](https://github.com/psf/black) | 2026-08-02 | `TODO` | — |
| `clang-format` | [llvm/llvm-project — clang-format](https://github.com/llvm/llvm-project/tree/main/clang/tools/clang-format) | 2026-08-01 | `TODO` | — |
| `cljstyle` | [greglook/cljstyle](https://github.com/greglook/cljstyle) | 2024-12-15 | `TODO` | — |
| `coffeelint` | [clutchski/coffeelint](https://github.com/clutchski/coffeelint) | 2021-10-19 | `TODO` | — |
| `csharpier` | [belav/csharpier](https://github.com/belav/csharpier) | 2026-06-07 | `DONE` | [`csharpier.lua`](./csharpier.lua) |
| `dartanalyzer` | [dart-lang/sdk — analyzer](https://github.com/dart-lang/sdk/tree/main/pkg/analyzer) | 2026-08-11 | `TODO` | — |
| `devskim` | [microsoft/DevSkim](https://github.com/microsoft/DevSkim) | 2026-07-31 | `TODO` | — |
| `dotnet-format` | [dotnet/format](https://github.com/dotnet/format) | 2024-03-07 | `TODO` | — |
| `dustilock` | [Checkmarx/dustilock](https://github.com/Checkmarx/dustilock) | 2026-05-22 | `TODO` | — |
| `eslint-plugin-jsonc` | [ota-meshi/eslint-plugin-jsonc](https://github.com/ota-meshi/eslint-plugin-jsonc) | 2026-04-10 | `TODO` | — |
| `gherkin-lint` | [gherkin-lint/gherkin-lint](https://github.com/gherkin-lint/gherkin-lint) | 2023-12-20 | `TODO` | — |
| `git_diff` | [git/git](https://github.com/git/git) | 2026-08-07 | `TODO` | — |
| `graphql-schema-linter` | [cjoudrey/graphql-schema-linter](https://github.com/cjoudrey/graphql-schema-linter) | 2022-05-06 | `TODO` | — |
| `grype` | [anchore/grype](https://github.com/anchore/grype) | 2026-07-31 | `TODO` | — |
| `helm` | [helm/helm](https://github.com/helm/helm) | 2026-08-04 | `TODO` | — |
| `isort` | [PyCQA/isort](https://github.com/PyCQA/isort) | 2026-08-11 | `TODO` | — |
| `jscpd` | [kucherenko/jscpd](https://github.com/kucherenko/jscpd) | 2026-07-24 | `TODO` | — |
| `kics` | [Checkmarx/kics](https://github.com/Checkmarx/kics) | 2026-04-21 | `TODO` | — |
| `kubeconform` | [yannh/kubeconform](https://github.com/yannh/kubeconform) | 2025-05-11 | `TODO` | — |
| `kubescape` | [kubescape/kubescape](https://github.com/kubescape/kubescape) | 2026-08-11 | `TODO` | — |
| `lintr` | [r-lib/lintr](https://github.com/r-lib/lintr) | 2026-07-10 | `TODO` | — |
| `lychee` | [lycheeverse/lychee](https://github.com/lycheeverse/lychee) | 2026-08-03 | `TODO` | — |
| `markdown-link-check` | [tcort/markdown-link-check](https://github.com/tcort/markdown-link-check) | 2026-06-02 | `TODO` | — |
| `markdown-table-formatter` | [nvuillam/markdown-table-formatter](https://github.com/nvuillam/markdown-table-formatter) | 2026-02-26 | `DONE` | [`markdown-table-formatter.lua`](./markdown-table-formatter.lua) |
| `npm-package-json-lint` | [tclindner/npm-package-json-lint](https://github.com/tclindner/npm-package-json-lint) | 2026-08-06 | `TODO` | — |
| `perlcritic` | [Perl-Critic/Perl-Critic](https://github.com/Perl-Critic/Perl-Critic) | 2024-07-07 | `TODO` | — |
| `php-cs-fixer` | [PHP-CS-Fixer/PHP-CS-Fixer](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) | 2026-07-24 | `TODO` | — |
| `phplint` | [overtrue/phplint](https://github.com/overtrue/phplint) | 2026-08-08 | `TODO` | — |
| `powershell` | [PowerShell/PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) | 2025-12-03 | `DONE` | [`psscryptanalyzer.lua`](./psscryptanalyzer.lua) |
| `powershell_formatter` | [PowerShell/PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) | 2025-12-03 | `TODO` | — |
| `prettier` | [prettier/prettier](https://github.com/prettier/prettier) | 2026-08-04 | `TODO` | — |
| `pyright` | [microsoft/pyright](https://github.com/microsoft/pyright) | 2026-07-28 | `TODO` | — |
| `raku` | [rakudo/rakudo](https://github.com/rakudo/rakudo) | 2026-08-11 | `TODO` | — |
| `remark-lint` | [remarkjs/remark-lint](https://github.com/remarkjs/remark-lint) | 2026-01-05 | `DONE` | [`remark-lint.lua`](./remark-lint.lua) |
| `roslynator` | [dotnet/roslynator](https://github.com/dotnet/roslynator) | 2026-08-07 | `TODO` | — |
| `ruff-format` | [astral-sh/ruff](https://github.com/astral-sh/ruff) | 2026-08-11 | `TODO` | — |
| `secretlint` | [secretlint/secretlint](https://github.com/secretlint/secretlint) | 2026-08-11 | `DONE` | [`secretlint.lua`](./secretlint.lua) |
| `sfdx-scanner-apex` | [forcedotcom/code-analyzer](https://github.com/forcedotcom/code-analyzer) | 2026-06-29 | `DONE` | [`code_analyzer.lua`](./code_analyzer.lua) |
| `sfdx-scanner-aura` | [forcedotcom/code-analyzer](https://github.com/forcedotcom/code-analyzer) | 2026-06-29 | `DONE` | [`code_analyzer.lua`](./code_analyzer.lua) |
| `sfdx-scanner-lwc` | [forcedotcom/code-analyzer](https://github.com/forcedotcom/code-analyzer) | 2026-06-29 | `DONE` | [`code_analyzer.lua`](./code_analyzer.lua) |
| `shfmt` | [mvdan/sh](https://github.com/mvdan/sh) | 2026-07-28 | `TODO` | — |
| `snakefmt` | [snakemake/snakefmt](https://github.com/snakemake/snakefmt) | 2026-05-22 | `TODO` | — |
| `standard` | [standard/standard](https://github.com/standard/standard) | 2025-07-11 | `TODO` | — |
| `stylua` | [JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua) | 2026-05-16 | `TODO` | — |
| `syft` | [anchore/syft](https://github.com/anchore/syft) | 2026-08-04 | `TODO` | — |
| `tekton-lint` | [IBM/tekton-lint](https://github.com/IBM/tekton-lint) | 2024-03-18 | `TODO` | — |
| `terraform-fmt` | [hashicorp/terraform](https://github.com/hashicorp/terraform) | 2026-08-05 | `TODO` | — |
| `terrascan` | [tenable/terrascan](https://github.com/tenable/terrascan) | 2024-03-07 | `TODO` | — |
| `terragrunt` | [gruntwork-io/terragrunt](https://github.com/gruntwork-io/terragrunt) | 2026-08-07 | `TODO` | — |
| `trivy-sbom` | [aquasecurity/trivy](https://github.com/aquasecurity/trivy) | 2026-07-16 | `TODO` | — |
| `trufflehog` | [trufflesecurity/trufflehog](https://github.com/trufflesecurity/trufflehog) | 2026-07-23 | `TODO` | — |
| `tsqllint` | [tsqllint/tsqllint](https://github.com/tsqllint/tsqllint) | 2022-05-22 | `TODO` | — |
| `v8r` | [nvuillam/v8r](https://github.com/nvuillam/v8r) | 2021-12-19 | `TODO` | — |

---

## Additional Local Configurations

These completed local modules are not represented by a matching row in the
current nvim-lint or MegaLinter source inventories above.

| Local config | State |
| --- | :---: |
| [`apkbuild-lint.lua`](./apkbuild-lint.lua) | `DONE` |
| [`bashate.lua`](./bashate.lua) | `DONE` |
| [`bashlint.lua`](./bashlint.lua) | `DONE` |
| [`betterleaks.lua`](./betterleaks.lua) | `DONE` |
| [`bibclean.lua`](./bibclean.lua) | `DONE` |
| [`bootlint.lua`](./bootlint.lua) | `DONE` |
| [`checkcode.lua`](./checkcode.lua) | `DONE` |
| [`cookstyle.lua`](./cookstyle.lua) | `DONE` |
| [`csslint.lua`](./csslint.lua) | `DONE` |
| [`cypher-lint.lua`](./cypher-lint.lua) | `DONE` |
| [`cython-lint.lua`](./cython-lint.lua) | `DONE` |
| [`desktopval.lua`](./desktopval.lua) | `DONE` |
| [`gdscript-linter.lua`](./gdscript-linter.lua) | `DONE` |
| [`html_validate.lua`](./html_validate.lua) | `DONE` |
| [`latex.lua`](./latex.lua) | `DONE` |
| [`lightning-flow-scanner.lua`](./lightning-flow-scanner.lua) | `DONE` |
| [`llvm-mc.lua`](./llvm-mc.lua) | `DONE` |
| [`lua.lua`](./lua.lua) | `DONE` |
| [`mdl.lua`](./mdl.lua) | `DONE` |
| [`naga.lua`](./naga.lua) | `DONE` |
| [`nvcc.lua`](./nvcc.lua) | `DONE` |
| [`scalafix.lua`](./scalafix.lua) | `DONE` |
| [`scalastyle.lua`](./scalastyle.lua) | `DONE` |
| [`scarb.lua`](./scarb.lua) | `DONE` |
| [`secfixes-check.lua`](./secfixes-check.lua) | `DONE` |
| [`textlint.lua`](./textlint.lua) | `DONE` |
| [`yara.lua`](./yara.lua) | `DONE` |
