<!-- /qompassai/Diver/lua/linters/README.md -->
<!-- Qompass AI Diver Linters Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Linters

> ELI5: this directory is a shelf of spell-checkers for code — one small
> file per linting tool that teaches Neovim how to run the tool on your
> buffer and turn its complaints into squiggly underlines.

## How it works

- `lua/linters/init.lua` is the native linter runner (no nvim-lint dependency).
  Its `M.module_sources` table registers every adapter as
  `name = 'linters.<module>'`; all registered adapters are loaded eagerly
  (unless the runner is embedded with `lazy = true`).
- `M.linters_by_ft` maps each Neovim filetype to the linter names that run on
  it. When a buffer is read, written, or left in Insert mode, an autocmd
  (250 ms debounce, files over 1 MB skipped) lints it with the filetype's
  configured linters.
- Each adapter file returns a definition table with a `cmd` (string, argv
  table, or function resolved per buffer), arguments, and a parser that
  converts the tool's output into `vim.diagnostic` entries.
- A registered adapter with no `linters_by_ft` entry is loaded but never
  auto-triggered; it can still be run on demand with `:Lint <name>`.
- User commands: `:Lint [names]` (current buffer), `:LintInfo`,
  `:LintDisable` / `:LintEnable`, `:LintReset`, `:LintValidate`. A linter
  whose binary is missing is reported as unavailable, not run.
- `M.validate()` reports any on-disk adapter missing from `module_sources`
  as an orphan; `M.unregistered_adapters` names the three intentional
  exclusions (factory modules and a disabled indexer).

## Inventory (alphabetical)

| Name | Config | Binary | Filetypes | Status | Install | Upstream |
| ---- | ------ | ------ | --------- | ------ | ------- | -------- |
| _salesforce-code-analyzer | [_salesforce-code-analyzer](_salesforce-code-analyzer.lua) | (factory) |  | inactive | [→ upstream](https://github.com/Flow-Scanner) | [link](https://github.com/Flow-Scanner) |
| actionlint | [actionlint](actionlint.lua) | actionlint | yaml.ghaction, yaml.github | active |  |  |
| alex | [alex](alex.lua) | alex | markdown, text | active | [→ upstream](https://github.com/get-alex/alex) | [link](https://github.com/get-alex/alex) |
| ameba | [ameba](ameba.lua) | ameba | crystal | active |  |  |
| android_lint | [android_lint](android_lint.lua) | android_lint | java, kotlin | active |  |  |
| ansible_lint | [ansible_lint](ansible_lint.lua) | ansible-lint | ansible, yaml.ansible | active |  |  |
| apkbuild-lint | [apkbuild-lint](apkbuild-lint.lua) | apkbuild-lint | apkbuild | active |  |  |
| bandit | [bandit](bandit.lua) | bandit | python | active | [→ upstream](https://github.com/PyCQA/bandit/tree/92ae8b82fb422a639f0ed8d99e96cea769594e08) | [link](https://github.com/PyCQA/bandit/tree/92ae8b82fb422a639f0ed8d99e96cea769594e08) |
| bash | [bash](bash.lua) | bash | bash | active | [→ upstream](https://www.gnu.org/software/bash/manual/bash.html) | [link](https://www.gnu.org/software/bash/manual/bash.html) |
| bashate | [bashate](bashate.lua) | bashate |  | active |  |  |
| bashlint | [bashlint](bashlint.lua) | bashlint |  | active |  |  |
| betterleaks | [betterleaks](betterleaks.lua) | betterleaks | dotenv | active |  |  |
| bibclean | [bibclean](bibclean.lua) | bibclean | bib, bibtex | active |  |  |
| biome | [biome](biome.lua) | biome | javascript, javascriptreact, json, jsx, tsx, typescript, typescriptreact | active | [→ upstream](https://biomejs.dev/linter/) | [link](https://biomejs.dev/linter/) |
| bootlint | [bootlint](bootlint.lua) | bootlint |  | active |  |  |
| buf_lint | [buf_lint](buf_lint.lua) | buf | proto | active | [→ upstream](https://buf.build/docs/lint/) | [link](https://buf.build/docs/lint/) |
| buildifier | [buildifier](buildifier.lua) | buildifier | bazel | active |  |  |
| cfn-lint | [cfn-lint](cfn-lint.lua) | cfn-lint | yaml, yml | active | [→ upstream](https://github.com/aws-cloudformation/cfn-lint) | [link](https://github.com/aws-cloudformation/cfn-lint) |
| checkbashisms | [checkbashisms](checkbashisms.lua) | checkbashisms | sh | active |  |  |
| checkcode | [checkcode](checkcode.lua) | checkcode | matlab | active | [→ upstream](https://www.mathworks.com/help/matlab/ref/checkcode.html) | [link](https://www.mathworks.com/help/matlab/ref/checkcode.html) |
| checkmake | [checkmake](checkmake.lua) | checkmake | make | active | [→ upstream](https://github.com/checkmake/checkmake) | [link](https://github.com/checkmake/checkmake) |
| checkpatch | [checkpatch](checkpatch.lua) | checkpatch.pl |  | active | [→ upstream](https://docs.kernel.org/dev-tools/checkpatch.html) | [link](https://docs.kernel.org/dev-tools/checkpatch.html) |
| checkstyle | [checkstyle](checkstyle.lua) | checkstyle |  | active | [→ upstream](https://github.com/checkstyle/checkstyle) | [link](https://github.com/checkstyle/checkstyle) |
| chktex | [chktex](chktex.lua) | chktex | latex, plaintex, tex | active |  |  |
| clangtidy | [clangtidy](clangtidy.lua) | clang-tidy | c, cpp | active |  |  |
| clazy | [clazy](clazy.lua) | clazy-standalone | cpp | active | [→ upstream](https://github.com/KDE/clazy) | [link](https://github.com/KDE/clazy) |
| clippy | [clippy](clippy.lua) | cargo | rust | active |  |  |
| clj-kondo | [clj-kondo](clj-kondo.lua) | clj-kondo | clojure | active |  |  |
| cmake-lint | [cmake-lint](cmake-lint.lua) | cmakelint | cmake | active |  |  |
| code_analyzer | [code_analyzer](code_analyzer.lua) | (factory) |  | inactive | [→ upstream](https://github.com/Flow-Scanner) | [link](https://github.com/Flow-Scanner) |
| codespell | [codespell](codespell.lua) | codespell | text | active | [→ upstream](https://github.com/codespell-project/codespell) | [link](https://github.com/codespell-project/codespell) |
| commitlint | [commitlint](commitlint.lua) | commitlint | gitcommit | active |  |  |
| cookstyle | [cookstyle](cookstyle.lua) | cookstyle | chef | active |  |  |
| cppcheck | [cppcheck](cppcheck.lua) | cppcheck | c, cpp | active |  |  |
| credo | [credo](credo.lua) | mix | elixir | active |  |  |
| csharpier | [csharpier](csharpier.lua) | csharpier | cs | active |  |  |
| cspell | [cspell](cspell.lua) | cspell | markdown, text | active | [→ upstream](https://github.com/streetsidesoftware/cspell) | [link](https://github.com/streetsidesoftware/cspell) |
| csslint | [csslint](csslint.lua) | csslint |  | active |  |  |
| cue | [cue](cue.lua) | cue | cue | active | [→ upstream](https://cuelang.org/docs/) | [link](https://cuelang.org/docs/) |
| cypher-lint | [cypher-lint](cypher-lint.lua) | cypher-lint | cypher | active |  |  |
| cython-lint | [cython-lint](cython-lint.lua) | cython-lint | cython | active |  |  |
| dash | [dash](dash.lua) | /usr/bin/env | sh | active | [→ upstream](http://gondor.apana.org.au/~herbert/dash/) | [link](http://gondor.apana.org.au/~herbert/dash/) |
| deadnix | [deadnix](deadnix.lua) | deadnix | nix | active |  |  |
| deno | [deno](deno.lua) | deno | javascript, javascriptreact, jsx, tsx, typescript, typescriptreact | active | [→ upstream](https://github.com/denoland/deno) | [link](https://github.com/denoland/deno) |
| desktopval | [desktopval](desktopval.lua) | desktop-file-validate | desktop | active |  |  |
| detect-secrets | [detect-secrets](detect-secrets.lua) | detect-secrets-hook | dotenv | active | [→ upstream](https://github.com/Yelp/detect-secrets) | [link](https://github.com/Yelp/detect-secrets) |
| detekt | [detekt](detekt.lua) | detekt | kotlin | active | [→ upstream](https://github.com/detekt/detekt) | [link](https://github.com/detekt/detekt) |
| dialyzer | [dialyzer](dialyzer.lua) | env | erlang | active | [→ upstream](https://www.erlang.org/docs/26/man/dialyzer.html) | [link](https://www.erlang.org/docs/26/man/dialyzer.html) |
| djlint | [djlint](djlint.lua) | djlint | htmlangular, htmldjango, jinja, jinja2 | active |  |  |
| dmypy | [dmypy](dmypy.lua) | dmypy | python | active | [→ upstream](https://github.com/python/mypy) | [link](https://github.com/python/mypy) |
| docker_compose | [docker_compose](docker_compose.lua) | python3 | yaml.docker-compose | active | [→ upstream](https://docs.docker.com/reference/cli/docker/compose/config/) | [link](https://docs.docker.com/reference/cli/docker/compose/config/) |
| dotenv-linter | [dotenv-linter](dotenv-linter.lua) | dotenv-linter | dotenv | active |  |  |
| dxc | [dxc](dxc.lua) | dxc | hlsl | active | [→ upstream](https://github.com/microsoft/DirectXShaderCompiler) | [link](https://github.com/microsoft/DirectXShaderCompiler) |
| editorconfig-checker | [editorconfig-checker](editorconfig-checker.lua) | editorconfig-checker | text | active | [→ upstream](https://editorconfig.org/) | [link](https://editorconfig.org/) |
| erb_lint | [erb_lint](erb_lint.lua) | erb_lint | eruby | active | [→ upstream](https://github.com/Shopify/erb_lint) | [link](https://github.com/Shopify/erb_lint) |
| eslint | [eslint](eslint.lua) | eslint | javascript, javascriptreact, jsx, tsx, typescript, typescriptreact, vue | active | [→ upstream](https://github.com/eslint/eslint) | [link](https://github.com/eslint/eslint) |
| eslint_d | [eslint_d](eslint_d.lua) | eslint_d | vue | active | [→ upstream](https://github.com/mantoni/eslint_d.js) | [link](https://github.com/mantoni/eslint_d.js) |
| eugene | [eugene](eugene.lua) | eugene | sql | active | [→ upstream](https://github.com/kaaveland/eugene) | [link](https://github.com/kaaveland/eugene) |
| fieldalignment | [fieldalignment](fieldalignment.lua) | fieldalignment | go | active |  |  |
| fish | [fish](fish.lua) | fish | fish | active | [→ upstream](https://github.com/fish-shell/fish-shell) | [link](https://github.com/fish-shell/fish-shell) |
| flake8 | [flake8](flake8.lua) | flake8 | python | active | [→ upstream](https://github.com/PyCQA/flake8) | [link](https://github.com/PyCQA/flake8) |
| flawfinder | [flawfinder](flawfinder.lua) | flawfinder | c, cpp | active | [→ upstream](https://github.com/david-a-wheeler/flawfinder) | [link](https://github.com/david-a-wheeler/flawfinder) |
| fortitude | [fortitude](fortitude.lua) | fortitude | fortran | active | [→ upstream](https://github.com/PlasmaFAIR/fortitude) | [link](https://github.com/PlasmaFAIR/fortitude) |
| fsharplint | [fsharplint](fsharplint.lua) | dotnet | fsharp | active | [→ upstream](https://github.com/fsprojects/FSharpLint) | [link](https://github.com/fsprojects/FSharpLint) |
| gawk | [gawk](gawk.lua) | /usr/bin/env | awk | active | [→ upstream](https://www.gnu.org/software/gawk/manual/html_node/Options.html) | [link](https://www.gnu.org/software/gawk/manual/html_node/Options.html) |
| gdlint | [gdlint](gdlint.lua) | gdlint | gdscript | active | [→ upstream](https://godotengine.org/asset-library/asset/4612) | [link](https://godotengine.org/asset-library/asset/4612) |
| gdscript-linter | [gdscript-linter](gdscript-linter.lua) | matlab | gdscript | active | [→ upstream](https://github.com/graydwarf/godot-gdscript-linter) | [link](https://github.com/graydwarf/godot-gdscript-linter) |
| ghdl | [ghdl](ghdl.lua) | ghdl | vhdl | active | [→ upstream](https://github.com/ghdl/ghdl) | [link](https://github.com/ghdl/ghdl) |
| glinter | [glinter](glinter.lua) | gleam | gleam | active | [→ upstream](https://github.com/pairshaped/glinter) | [link](https://github.com/pairshaped/glinter) |
| glslc | [glslc](glslc.lua) | glslc | glsl | active | [→ upstream](https://github.com/google/shaderc) | [link](https://github.com/google/shaderc) |
| golangcilint | [golangcilint](golangcilint.lua) | golangci-lint | go | active |  |  |
| hadolint | [hadolint](hadolint.lua) | hadolint | dockerfile | active | [→ upstream](https://github.com/hadolint/hadolint) | [link](https://github.com/hadolint/hadolint) |
| herb | [herb](herb.lua) | herb-lint | eruby | active | [→ upstream](https://herb-tools.dev/projects/linter) | [link](https://herb-tools.dev/projects/linter) |
| hledger | [hledger](hledger.lua) | hledger |  | active |  |  |
| hlint | [hlint](hlint.lua) | hlint | haskell | active | [→ upstream](https://github.com/ndmitchell/hlint) | [link](https://github.com/ndmitchell/hlint) |
| html-tidy | [html-tidy](html-tidy.lua) | tidy | html | active | [→ upstream](https://www.html-tidy.org/) | [link](https://www.html-tidy.org/) |
| html_validate | [html_validate](html_validate.lua) | html-validate | html | active |  |  |
| htmlhint | [htmlhint](htmlhint.lua) | detect-secrets-hook |  | active | [→ upstream](https://htmlhint.com/configuration/) | [link](https://htmlhint.com/configuration/) |
| janet | [janet](janet.lua) | janet | janet | active |  |  |
| joker | [joker](joker.lua) | joker |  | active | [→ upstream](https://github.com/candid82/joker) | [link](https://github.com/candid82/joker) |
| jq | [jq](jq.lua) | jq | json | active | [→ upstream](https://jqlang.org/manual/) | [link](https://jqlang.org/manual/) |
| json5 | [json5](json5.lua) | npx | json5 | active |  |  |
| json_tool | [json_tool](json_tool.lua) | python3 | json | active | [→ upstream](https://docs.python.org/3/library/json.html) | [link](https://docs.python.org/3/library/json.html) |
| kics | [kics](kics.lua) | python3 | terraform | active | [→ upstream](https://github.com/Checkmarx/kics) | [link](https://github.com/Checkmarx/kics) |
| ksh | [ksh](ksh.lua) | ksh | sh | active | [→ upstream](https://github.com/ksh93/ksh) | [link](https://github.com/ksh93/ksh) |
| ktlint | [ktlint](ktlint.lua) | ktlint | kotlin | active | [→ upstream](https://github.com/pinterest/ktlint) | [link](https://github.com/pinterest/ktlint) |
| lacheck | [lacheck](lacheck.lua) | lacheck |  | active |  |  |
| latex | [latex](latex.lua) | latex |  | inactive |  |  |
| lightning-flow-scanner | [lightning-flow-scanner](lightning-flow-scanner.lua) | lightning-flow-scanner |  | active |  |  |
| lint-openapi | [lint-openapi](lint-openapi.lua) | lint-openapi | openapi, swagger, yaml.openapi | active |  |  |
| llvm-mc | [llvm-mc](llvm-mc.lua) | llvm-mc | asm | active |  |  |
| luac | [luac](luac.lua) | luac |  | active |  |  |
| luacheck | [luacheck](luacheck.lua) | luacheck | lua | active |  |  |
| mado | [mado](mado.lua) | mado |  | active |  |  |
| mago_analyze | [mago_analyze](mago_analyze.lua) | mago | php | active | [→ upstream](https://github.com/carthage-software/mago) | [link](https://github.com/carthage-software/mago) |
| markdown-table-formatter | [markdown-table-formatter](markdown-table-formatter.lua) | markdown-table-formatter | markdown | active |  |  |
| markdownlint | [markdownlint](markdownlint.lua) | markdownlint |  | active |  |  |
| markdownlint-cli2 | [markdownlint-cli2](markdownlint-cli2.lua) | markdownlint-cli2 | markdown, markdown.mdx, quarto | active | [→ upstream](https://github.com/DavidAnson/markdownlint-cli2) | [link](https://github.com/DavidAnson/markdownlint-cli2) |
| markuplint | [markuplint](markuplint.lua) | markuplint | html | active | [→ upstream](https://github.com/markuplint/markuplint) | [link](https://github.com/markuplint/markuplint) |
| markuplint-cli2 | [markuplint-cli2](markuplint-cli2.lua) | markdownlint-cli2 | html | active | [→ upstream](https://github.com/DavidAnson/markdownlint-cli2) | [link](https://github.com/DavidAnson/markdownlint-cli2) |
| mbake | [mbake](mbake.lua) | mbake | make | active |  |  |
| mdl | [mdl](mdl.lua) | mdl |  | active |  |  |
| mh_lint | [mh_lint](mh_lint.lua) | mh_lint | matlab | active | [→ upstream](https://florianschanda.github.io/miss_hit/lint.html) | [link](https://florianschanda.github.io/miss_hit/lint.html) |
| mypy | [mypy](mypy.lua) | mypy | python | active | [→ upstream](https://github.com/python/mypy) | [link](https://github.com/python/mypy) |
| naga | [naga](naga.lua) | naga | wgsl | active |  |  |
| npm_groovy_lint | [npm_groovy_lint](npm_groovy_lint.lua) | npm_groovy_lint | groovy | active | [→ upstream](https://github.com/nvuillam/npm-groovy-lint/tree/2080dffcddb215d409b149ccc7f595cb242a6209) | [link](https://github.com/nvuillam/npm-groovy-lint/tree/2080dffcddb215d409b149ccc7f595cb242a6209) |
| nvcc | [nvcc](nvcc.lua) | nvcc | cuda | active |  |  |
| oelint-adv | [oelint-adv](oelint-adv.lua) | oelint-adv | bitbake | active | [→ upstream](https://github.com/priv-kweihmann/oelint-adv) | [link](https://github.com/priv-kweihmann/oelint-adv) |
| opa_checks | [opa_checks](opa_checks.lua) | opa_checks | rego | active | [→ upstream](https://github.com/cds-snc/opa_checks/tree/9063d900522d427869a0f744b32946b49d719076) | [link](https://github.com/cds-snc/opa_checks/tree/9063d900522d427869a0f744b32946b49d719076) |
| oxlint | [oxlint](oxlint.lua) | oxlint | javascript, javascriptreact, jsx, tsx, typescript, typescriptreact | active |  |  |
| panache | [panache](panache.lua) | panache | markdown, quarto | active | [→ upstream](https://github.com/jolars/panache) | [link](https://github.com/jolars/panache) |
| perlcritic | [perlcritic](perlcritic.lua) | perlcritic | perl | active | [→ upstream](https://github.com/Perl-Critic/Perl-Critic) | [link](https://github.com/Perl-Critic/Perl-Critic) |
| php | [php](php.lua) | php | php | active | [→ upstream](https://www.php.net) | [link](https://www.php.net) |
| phpcs | [phpcs](phpcs.lua) | phpcs | php | active |  |  |
| phpinsights | [phpinsights](phpinsights.lua) | phpinsights | php | active |  |  |
| phpmd | [phpmd](phpmd.lua) | phpmd | php | active |  |  |
| phpstan | [phpstan](phpstan.lua) | phpstan | php | active | [→ upstream](https://github.com/phpstan/phpstan/releases/tag/2.2.14) | [link](https://github.com/phpstan/phpstan/releases/tag/2.2.14) |
| pmd | [pmd](pmd.lua) | pmd |  | active | [→ upstream](https://github.com/pmd/pmd) | [link](https://github.com/pmd/pmd) |
| pony-lint | [pony-lint](pony-lint.lua) | pony-lint | pony | active | [→ upstream](https://www.ponylang.io/use/linting/) | [link](https://www.ponylang.io/use/linting/) |
| prisma-lint | [prisma-lint](prisma-lint.lua) | prisma-lint | prisma | active | [→ upstream](https://github.com/loop-payments/prisma-lint/tree/7aa8ad22490e4bf599594e004ccf335a595240f3) | [link](https://github.com/loop-payments/prisma-lint/tree/7aa8ad22490e4bf599594e004ccf335a595240f3) |
| proselint | [proselint](proselint.lua) | proselint | mail | active | [→ upstream](https://github.com/amperser/proselint) | [link](https://github.com/amperser/proselint) |
| protolint | [protolint](protolint.lua) | protolint | proto | active | [→ upstream](https://github.com/yoheimuta/protolint) | [link](https://github.com/yoheimuta/protolint) |
| psalm | [psalm](psalm.lua) | Neovim Psalm | php | active | [→ upstream](https://github.com/vimeo/psalm/releases/tag/6.17.1) | [link](https://github.com/vimeo/psalm/releases/tag/6.17.1) |
| psscryptanalyzer | [psscryptanalyzer](psscryptanalyzer.lua) | pwsh | powershell | active |  |  |
| puppet-lint | [puppet-lint](puppet-lint.lua) | puppet-lint | puppet | active |  |  |
| pycodestyle | [pycodestyle](pycodestyle.lua) | pycodestyle | python | active | [→ upstream](https://github.com/PyCQA/pycodestyle) | [link](https://github.com/PyCQA/pycodestyle) |
| pylint | [pylint](pylint.lua) | pylint | python | active | [→ upstream](https://github.com/pylint-dev/pylint) | [link](https://github.com/pylint-dev/pylint) |
| pyrefly | [pyrefly](pyrefly.lua) | pyrefly |  | active |  |  |
| quick-lint-js | [quick-lint-js](quick-lint-js.lua) | quick-lint-js | javascript, javascriptreact, jsx, tsx, typescript, typescriptreact | active | [→ upstream](https://github.com/quick-lint/quick-lint-js) | [link](https://github.com/quick-lint/quick-lint-js) |
| redocly | [redocly](redocly.lua) | redocly | openapi, swagger, yaml.openapi | active | [→ upstream](https://github.com/Redocly/redocly-cli) | [link](https://github.com/Redocly/redocly-cli) |
| regal | [regal](regal.lua) | regal | rego | active | [→ upstream](https://github.com/open-policy-agent/regal) | [link](https://github.com/open-policy-agent/regal) |
| remark-lint | [remark-lint](remark-lint.lua) | remark |  | active |  |  |
| revive | [revive](revive.lua) | revive |  | active |  |  |
| rpmlint | [rpmlint](rpmlint.lua) | rpmlint | spec | active | [→ upstream](https://github.com/rpm-software-management/rpmlint) | [link](https://github.com/rpm-software-management/rpmlint) |
| rst-lint | [rst-lint](rst-lint.lua) | rst-lint | rst | active | [→ upstream](https://github.com/twolfson/restructuredtext-lint) | [link](https://github.com/twolfson/restructuredtext-lint) |
| rstcheck | [rstcheck](rstcheck.lua) | rstcheck | rst | active |  |  |
| rubocop | [rubocop](rubocop.lua) | rubocop | ruby | active | [→ upstream](https://github.com/rubocop/rubocop) | [link](https://github.com/rubocop/rubocop) |
| ruby | [ruby](ruby.lua) | ruby | ruby | active | [→ upstream](https://github.com/ruby/ruby) | [link](https://github.com/ruby/ruby) |
| ruff | [ruff](ruff.lua) | ruff | python | active | [→ upstream](https://github.com/astral-sh/ruff) | [link](https://github.com/astral-sh/ruff) |
| rumdl | [rumdl](rumdl.lua) | rumdl | markdown.mdx, quarto | active |  |  |
| scalafix | [scalafix](scalafix.lua) | scalafix | scala | active |  |  |
| scalastyle | [scalastyle](scalastyle.lua) | scalastyle | scala | active |  |  |
| scarb | [scarb](scarb.lua) | scarb | cairo | active |  |  |
| secfixes-check | [secfixes-check](secfixes-check.lua) | secfixes-check | apkbuild | active |  |  |
| secretlint | [secretlint](secretlint.lua) | secretlint | dotenv | active |  |  |
| selene | [selene](selene.lua) | selene | lua | active | [→ upstream](https://github.com/Kampfkarren/selene) | [link](https://github.com/Kampfkarren/selene) |
| shellcheck | [shellcheck](shellcheck.lua) | shellcheck | bash, sh | active |  |  |
| slang | [slang](slang.lua) | slang | systemverilog | active | [→ upstream](https://github.com/MikePopoloski/slang) | [link](https://github.com/MikePopoloski/slang) |
| snakefmt | [snakefmt](snakefmt.lua) | snakefmt | snakemake | active | [→ upstream](https://github.com/snakemake/snakefmt) | [link](https://github.com/snakemake/snakefmt) |
| snakemake | [snakemake](snakemake.lua) | snakemake | snakemake | active | [→ upstream](https://snakemake.readthedocs.io/en/stable/snakefiles/best_practices.html) | [link](https://snakemake.readthedocs.io/en/stable/snakefiles/best_practices.html) |
| solhint | [solhint](solhint.lua) | solhint | solidity | active | [→ upstream](https://github.com/protofire/solhint) | [link](https://github.com/protofire/solhint) |
| spectral | [spectral](spectral.lua) | spectral | json, openapi, swagger, yaml, yaml.openapi | active | [→ upstream](https://github.com/stoplightio/spectral) | [link](https://github.com/stoplightio/spectral) |
| sphinx-lint | [sphinx-lint](sphinx-lint.lua) | sphinx-lint | rst | active |  |  |
| sqlfluff | [sqlfluff](sqlfluff.lua) | sqlfluff | sql | active | [→ upstream](https://docs.sqlfluff.com/en/stable/) | [link](https://docs.sqlfluff.com/en/stable/) |
| sqruff | [sqruff](sqruff.lua) | sqruff | sql | active | [→ upstream](https://github.com/quarylabs/sqruff) | [link](https://github.com/quarylabs/sqruff) |
| squawk | [squawk](squawk.lua) | squawk | sql | active | [→ upstream](https://github.com/sbdchd/squawk/tree/2167b892a6f204c96b08b522df782a88898c1d2d) | [link](https://github.com/sbdchd/squawk/tree/2167b892a6f204c96b08b522df782a88898c1d2d) |
| staticcheck | [staticcheck](staticcheck.lua) | staticcheck | go | active | [→ upstream](https://staticcheck.dev/) | [link](https://staticcheck.dev/) |
| statix | [statix](statix.lua) | statix | nix | active |  |  |
| stylelint | [stylelint](stylelint.lua) | ./node_modules/.bin/stylelint | css, sass, scss | active | [→ upstream](https://stylelint.io/) | [link](https://stylelint.io/) |
| svlint | [svlint](svlint.lua) | vsg | systemverilog | active | [→ upstream](https://github.com/jeremiah-c-leary/vhdl-style-guide) | [link](https://github.com/jeremiah-c-leary/vhdl-style-guide) |
| systemd-analyze | [systemd-analyze](systemd-analyze.lua) | systemd-analyze | systemd | active | [→ upstream](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html) | [link](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html) |
| systemdlint | [systemdlint](systemdlint.lua) | systemdlint | systemd | active | [→ upstream](https://github.com/priv-kweihmann/systemdlint) | [link](https://github.com/priv-kweihmann/systemdlint) |
| textlint | [textlint](textlint.lua) | textlint |  | active | [→ upstream](https://textlint.org/docs/cli/) | [link](https://textlint.org/docs/cli/) |
| tflint | [tflint](tflint.lua) | tflint | terraform, terraform-vars | active | [→ upstream](https://github.com/terraform-linters/tflint) | [link](https://github.com/terraform-linters/tflint) |
| tombi | [tombi](tombi.lua) | tombi | toml | active | [→ upstream](https://github.com/tombi-toml/tombi) | [link](https://github.com/tombi-toml/tombi) |
| trivy | [trivy](trivy.lua) | trivy | dockerfile | active | [→ upstream](https://github.com/aquasecurity/trivy) | [link](https://github.com/aquasecurity/trivy) |
| twig_cs | [twig_cs](twig_cs.lua) | ./vendor/bin/twig-cs-fixer | twig | active |  |  |
| typos | [typos](typos.lua) | typos | text | active |  |  |
| unmake | [unmake](unmake.lua) | unmake | make | active | [→ upstream](https://github.com/mcandre/unmake) | [link](https://github.com/mcandre/unmake) |
| v8r | [v8r](v8r.lua) | v8r | json, yaml | active | [→ upstream](https://github.com/chris48s/v8r) | [link](https://github.com/chris48s/v8r) |
| vacuum | [vacuum](vacuum.lua) | vacuum | openapi, swagger, yaml.openapi | active | [→ upstream](https://github.com/daveshanley/vacuum) | [link](https://github.com/daveshanley/vacuum) |
| vale | [vale](vale.lua) | vale | text | active | [→ upstream](https://github.com/errata-ai/vale) | [link](https://github.com/errata-ai/vale) |
| vint | [vint](vint.lua) | vint | vim | active |  |  |
| vsg | [vsg](vsg.lua) | vsg | vhdl | active | [→ upstream](https://github.com/jeremiah-c-leary/vhdl-style-guide) | [link](https://github.com/jeremiah-c-leary/vhdl-style-guide) |
| vulture | [vulture](vulture.lua) | vulture | python | active | [→ upstream](https://github.com/jendrikseipp/vulture/tree/b0f67ba0044693aa9ec0d38fe460590facc98004) | [link](https://github.com/jendrikseipp/vulture/tree/b0f67ba0044693aa9ec0d38fe460590facc98004) |
| write_good | [write_good](write_good.lua) | write-good | markdown, text | active | [→ upstream](https://github.com/btford/write-good) | [link](https://github.com/btford/write-good) |
| yamllint | [yamllint](yamllint.lua) | yamllint | yaml, yml | active | [→ upstream](https://yamllint.readthedocs.io/en/stable/quickstart.html) | [link](https://yamllint.readthedocs.io/en/stable/quickstart.html) |
| yara | [yara](yara.lua) | yarac | yara | active | [→ upstream](https://github.com/VirusTotal/yara/tree/84b0e3cc0e42f8f8e6b84d19c97ec3ac6ff8aee8) | [link](https://github.com/VirusTotal/yara/tree/84b0e3cc0e42f8f8e6b84d19c97ec3ac6ff8aee8) |
| yq | [yq](yq.lua) | yq | yaml, yml | active | [→ upstream](https://github.com/mikefarah/yq/tree/c14f446382944492701b16c1ddb48bb9dbe683e3) | [link](https://github.com/mikefarah/yq/tree/c14f446382944492701b16c1ddb48bb9dbe683e3) |
| zizmor | [zizmor](zizmor.lua) | zizmor | yaml.ghaction, yaml.github | active | [→ upstream](https://github.com/zizmorcore/zizmor) | [link](https://github.com/zizmorcore/zizmor) |
| zlint | [zlint](zlint.lua) | zlint | zig, zine, zon | active | [→ upstream](https://github.com/DonIsaac/zlint) | [link](https://github.com/DonIsaac/zlint) |
| zsh | [zsh](zsh.lua) | zsh | zsh | active | [→ upstream](https://www.zsh.org) | [link](https://www.zsh.org) |

## Install notes

Most of these tools come from their language's own ecosystem: JavaScript
linters via `npm`, Python linters via `pip`/`uv`, Ruby via `gem`, Go via
`go install`, Rust via `cargo install`, and many via your system package
manager (`paru`/`pacman` on Arch, `brew` on macOS). Each row's Install
column points at the tool's own project page, which documents the
canonical install method — use that rather than guessing a package name.
`:LintInfo` shows which linters are configured for the current buffer and
flags any whose binary is missing from `PATH`.

## Reference

- [nvim-lint](https://github.com/mfussenegger/nvim-lint) — adapter schema this
  directory's definitions are modeled on (cited as a source in `init.lua`)
- [MegaLinter supported linters](https://megalinter.io/8/supported-linters/) —
  inventory the linter set was cross-checked against
- [qompassai/diver](https://github.com/qompassai/diver) — upstream repo
