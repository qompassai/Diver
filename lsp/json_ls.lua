-- /qompassai/Diver/lsp/jsonls.lua
-- Qompass AI Qompass AI Javascript Object Notation (JSON) LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
---------------------------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'vscode-json-language-server',
        '--stdio',
    },
    filetypes = {
        'json',
        'jsonc',
        'json5',
    },
    init_options = {
        customCapabilities = {
            rangeFormatting = {
                editLimit = 1000,
            },
        },
        handledSchemaProtocols = {
            'file',
            'http',
            'https',
        },
        provideFormatter = false,
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.git',
    },
    settings = {
        http = {
            proxy = '',
            proxyStrictSSL = true,
        },
        json = {
            format = {
                enable = true,
            },
            jsonFoldingLimit = 5000,
            jsoncFoldingLimit = 5000,
            resultLimit = 10000,

            schemas = {
                {
                    description = 'Angular configuration file',
                    fileMatch = {
                        'angular.json',
                        'angular.jsonc',
                    },
                    url = 'https://raw.githubusercontent.com/angular/angular-cli/master/packages/angular/cli/lib/config/workspace-schema.json',
                },
                {
                    description = 'Angular CLI configuration file',
                    fileMatch = {
                        '.angular-cli.json',
                        'angular-cli.json',
                    },
                   url =  'https://raw.githubusercontent.com/angular/angular-cli/v10.1.6/packages/angular/cli/lib/config/schema.json',
                },
                {
                    description = 'asm-lsp configuration',
                    fileMatch = {
                        '.asm-lsp.toml',
                        'asm-lsp.toml',
                    },
                    url = 'https://raw.githubusercontent.com/bergercookie/asm-lsp/master/asm-lsp_config_schema.json',
                },
                {
                    description = 'AssemblyScript config (asconfig.json)',
                    fileMatch = { 'asconfig.json' },
                    url = 'https://www.schemastore.org/asconfig-schema.json',
                },
                {
                    description = 'ast-grep project config',
                    fileMatch = { 'sgconfig.yml', 'sgconfig.yaml' },
                    url = 'https://raw.githubusercontent.com/ast-grep/ast-grep/main/schemas/project.json',
                },
                {
                    description = 'ast-grep rule config',
                    fileMatch = {
                        '**/.astgrep/rules/**/*.yaml',
                        '**/.astgrep/rules/**/*.yml',
                        '**/.ast-grep/rules/**/*.yaml',
                        '**/.ast-grep/rules/**/*.yml',
                        '**/ast-grep/rules/**/*.yaml',
                        '**/ast-grep/rules/**/*.yml',
                        '**/astgrep/rules/**/*.yaml',
                        '**/astgrep/rules/**/*.yml',
                    },
                    url = 'https://raw.githubusercontent.com/ast-grep/ast-grep/main/schemas/rule.json',
                },
                {
                    description = 'Air (R formatter and language server)',
                    fileMatch = { 'air.toml', '.air.toml' },
                    url = 'https://github.com/posit-dev/air/releases/latest/download/air.schema.json',
                },
                {
                    description = 'Azure Pipelines YAML pipelines definition',
                    fileMatch = {
                        'azure-pipelines.yml',
                        'azure-pipelines.yaml',
                    },
                    url = 'https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json',
                },
                {
                    description = 'Unity 3D assembly definition file',
                    fileMatch = {
                        '*.asmdef',
                    },
                    url = 'https://www.schemastore.org/asmdef.json',
                },
                {
                    description = 'Babel configuration file',
                    fileMatch = {
                        '.babelrc',
                        '.babelrc.json',
                        'babel.config.json',
                    },
                    url = 'https://www.schemastore.org/babelrc.json',
                },
                {
                    description = 'Bacon',
                    filmatch = {
                        'bacon.toml',
                        '**/bacon/prefs.toml',
                    },
                    url = 'https://dystroy.org/bacon/.bacon.schema.json',
                },
                {
                    description = 'BigQuery table',
                    fileMatch = {
                        '*.bigquery.json',
                    },
                    url = 'https://www.schemastore.org/bigquery-table.json',
                },
                {
                    description = 'Biome',
                    fileMatch = {
                        '.biome.jsonc',
                        '**/.biome.jsonc',
                        '~/.config/biome/biome.jsonc',
                    },
                    url = 'https://biomejs.dev/schemas/latest/schema.json',
                },
                {
                    description = 'Webpack bootstrap-loader configuration file',
                    fileMatch = {
                        '.bootstraprc',
                    },
                    url = 'https://www.schemastore.org/bootstraprc.json',
                },
                {
                    description = 'Bower package description file',
                    fileMatch = {
                        'bower.json',
                        '.bower.json',
                    },
                    url = 'https://www.schemastore.org/bower.json',
                },
                {
                    description = 'Bower configuration file',
                    fileMatch = {
                        '.bowerrc',
                    },
                    url = 'https://www.schemastore.org/bowerrc.json',
                },
                {
                    description = 'browsh configuration',
                    fileMatch = {
                        '**/browsh/config.toml',
                    },
                    url = 'https://raw.githubusercontent.com/browsh-org/browsh/master/webext/assets/browsh-schema.json',
                },
                {
                    description = 'bun.lock file',
                    fileMatch = {
                        'bun.lock',
                    },
                    url = 'https://www.schemastore.org/bun-lock.json',
                },
                {
                    description = 'bundleconfig.json files',
                    fileMatch = {
                        'bundleconfig.json',
                    },
                    url = 'https://www.schemastore.org/bundleconfig.json',
                },
                {
                    description = 'bunfig.toml file',
                    fileMatch = {
                        'bunfig.toml',
                    },
                    url = 'https://www.schemastore.org/bunfig.json',
                },
                {
                    description = 'Bleep (Scala build tool)',
                    fileMatch = {
                        'bleep.yaml',
                        'bleep.yml',
                    },
                    url = 'https://raw.githubusercontent.com/oyvindberg/bleep/master/schema.json',
                },
                {
                    description = 'Cargo',
                    fileMatch = {
                        'Cargo.toml.json',
                    },
                    url = 'https://json.schemastore.org/cargo.json',
                },
                {
                    description = 'Chrome Extension manifest file',
                    fileMatch = {
                        'manifest.json',
                        'manifest.jsonc',
                    },
                    url = 'https://www.schemastore.org/chrome-manifest.json',
                },
                {
                    description = 'Chrome extension localization file',
                    fileMatch = {
                        '**/_locales/*/messages.json',
                    },
                    url = 'https://www.schemastore.org/chrome-extension-locales-messages.json',
                },
                {
                    description = 'CircleCI config files',
                    fileMatch = {
                        '**/.circleci/config.yml',
                    },
                    url = 'https://www.schemastore.org/circleciconfig.json',
                },
                {
                    description = 'clangd configuration',
                    fileMatch = {
                        '.clangd',
                        '.clangd.yml',
                        '.clangd.yaml',
                        '**/clangd/config.yaml',
                    },
                    url = 'https://www.schemastore.org/clangd.json',
                },
                {
                    description = 'clang-tidy configuration',
                    fileMatch = {
                        '.clang-tidy',
                        'clang-tidy.yml',
                        'clang-tidy.yaml',
                    },
                    url = 'https://www.schemastore.org/clang-tidy.json',
                },
                {
                    description = 'Claude Code Settings',
                    fileMatch = {
                        '**/.claude/settings.json',
                    },
                    url = 'https://www.schemastore.org/claude-code-settings.json',
                },
                {
                    description = 'CMake Presets',
                    fileMatch = {
                        'CMakePresets.json',
                        'CMakeUserPresets.json',
                    },
                    url = 'https://raw.githubusercontent.com/Kitware/CMake/master/Help/manual/presets/schema.json',
                },
                {
                    description = 'CoffeeLint configuration file',
                    fileMatch = {
                        'coffeelint.json',
                    },
                    url = 'https://www.schemastore.org/coffeelint.json',
                },
                {
                    description = 'compilerconfig.json files',
                    fileMatch = { 'compilerconfig.json' },
                    url = 'https://www.schemastore.org/compilerconfig.json',
                },
                {
                    description = 'LLVM compilation database (compile_commands.json)',
                    fileMatch = { 'compile_commands.json' },
                    url = 'https://www.schemastore.org/compile-commands.json',
                },
                {
                    description = 'PHP Composer configuration file',
                    fileMatch = { 'composer.json' },
                    url = 'https://getcomposer.org/schema.json',
                },
                {
                    description = 'conda-forge configuration file',
                    fileMatch = { 'conda-forge.yml' },
                    url = 'https://raw.githubusercontent.com/conda-forge/conda-smithy/main/conda_smithy/data/conda-forge.json',
                },
                {
                    description = 'CSpell configuration file',
                    fileMatch = {
                        '.cspell.json',
                        'cspell.json',
                        '.cSpell.json',
                        'cSpell.json',
                        'cspell.config.json',
                        'cspell.config.yaml',
                        'cspell.config.yml',
                        'cspell.yaml',
                        'cspell.yml',
                    },
                   url =  'https://raw.githubusercontent.com/streetsidesoftware/cspell/main/packages/cspell-types/cspell.schema.json',
                },
                {
                    description = 'CSS Comb configuration file',
                    fileMatch = { '.csscomb.json' },
                    url = 'https://www.schemastore.org/csscomb.json',
                },
                {
                    description = 'CSS Lint configuration file',
                    fileMatch = { '.csslintrc' },
                    url = 'https://www.schemastore.org/csslintrc.json',
                },
                {
                    description = 'CVE record format',
                    fileMatch = { 'CVE-*.json' },
                  url =   'https://raw.githubusercontent.com/CVEProject/cve-schema/master/schema/docs/CVE_Record_Format_bundled.json',
                },
                {
                    description = 'Cypress.io test runner configuration file',
                    fileMatch = {
                        'cypress.json',
                    },
                    url = 'https://on.cypress.io/cypress.schema.json',
                },
                {
                    description = 'Dart build configuration',
                    url = 'https://www.schemastore.org/dart-build.json',
                },
                {
                    description = 'Dart test configuration',
                    fileMatch = {
                        'dart_test.yaml',
                    },
                    url = 'https://www.schemastore.org/dart-test.json',
                },
                {
                    description = 'dbt Dependencies',
                    fileMatch = { '**/*dbt*/dependencies.yaml', '**/*dbt*/dependencies.yml' },
                    url = 'https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest/dependencies-latest.json',
                },
                {
                    description = 'dbt Project',
                    fileMatch = { 'dbt_project.yaml', 'dbt_project.yml' },
                    url = 'https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest/dbt_project-latest.json',
                },
                {
                    description = 'dbt Packages',
                    fileMatch = { '**/*dbt*/packages.yaml', '**/*dbt*/packages.yml' },
                    url = 'https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest/packages-latest.json',
                },
                {
                    description = 'dbt Selectors',
                    fileMatch = { '**/*dbt*/selectors.yaml', '**/*dbt*/selectors.yml' },
                    url = 'https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest/selectors-latest.json',
                },
                {
                    description = 'dbt YAML files',
                    fileMatch = {
                        '**/*dbt*/macros/**/*.yaml',
                        '**/*dbt*/macros/**/*.yml',
                        '**/*dbt*/models/**/*.yaml',
                        '**/*dbt*/models/**/*.yml',
                        '**/*dbt*/seeds/**/*.yaml',
                        '**/*dbt*/seeds/**/*.yml',
                        '**/*dbt*/snapshots/**/*.yaml',
                        '**/*dbt*/snapshots/**/*.yml',
                    },
                    url = 'https://raw.githubusercontent.com/dbt-labs/dbt-jsonschema/main/schemas/latest/dbt_yml_files-latest.json',
                },
                {
                    description = 'Detekt Configuration File',
                    fileMatch = { 'detekt.yml', 'detekt.yaml' },
                    url = 'https://www.schemastore.org/detekt-1.22.0.json',
                },
                {
                    description = 'Discord Webhook',
                    -- no specific fileMatch in the entry; match by $schema or manual association
                    url = 'https://raw.githubusercontent.com/AxoCode/json-schema/master/discord/webhook.json',
                },
                {
                    description = '.NET Release Index manifest',
                    fileMatch = { 'dotnet-release-index.json' },
                    url = 'https://www.schemastore.org/dotnet-releases-index.json',
                },
                {
                    description = '.NET tools manifest file',
                    fileMatch = { 'dotnet-tools.json' },
                    url = 'https://www.schemastore.org/dotnet-tools.json',
                },
                {
                    description = '.NET CLI template host files',
                    fileMatch = { 'dotnetcli.host.json' },
                    url = 'https://www.schemastore.org/dotnetcli.host.json',
                },
                {
                    description = 'dprint configuration file',
                    fileMatch = {
                        'dprint.json',
                        'dprint.jsonc',
                        '.dprint.json',
                        '.dprint.jsonc',
                    },
                    url = 'https://dprint.dev/schemas/v0.json',
                },
                {
                    description = 'Drone CI configuration file',
                    fileMatch = {
                        '.drone.yml',
                    },
                    url = 'https://www.schemastore.org/drone.json',
                },
                {
                    description = 'Docker daemon configuration',
                    fileMatch = {
                        'dockerd.json',
                        'dockerd.jsonc',
                        'docker.json',
                        'docker.jsonc',
                    },
                    url = 'https://www.schemastore.org/dockerd.json',
                },
                {
                    description = 'Docker Bake configuration file',
                    fileMatch = { 'docker-bake.json', 'docker-bake.override.json' },
                    url = 'https://www.schemastore.org/docker-bake.json',
                },
                {
                    description = 'Docker-Compose',
                    fileMatch = {
                        'docker-compose*.yml',
                        'docker-compose*.yaml',
                    },
                    url = 'https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json',
                },
                {
                    description = 'docker-seq configuration',
                    fileMatch = {
                        'docker-seq.yaml',
                        'docker-seq.json',
                        'docker-seq.jsonc',
                        'docker-seq.yml',
                        '*.docker-seq.yaml',
                        '*.docker-seq.json',
                        '*.docker-seq.jsonc',
                        '*.docker-seq.yml',
                    },
                    url = 'https://gitlab.com/sbenv/veroxis/docker-seq/-/raw/HEAD/docker-seq.schema.json',
                },
                {
                    description = 'Drupal Breakpoints',
                    fileMatch = { '*.breakpoints.yml' },
                    url = 'https://www.schemastore.org/drupal-breakpoints.json',
                },
                {
                    description = 'Drupal Info',
                    fileMatch = {
                        '*.info.yml',
                    },
                    url = 'https://www.schemastore.org/drupal-info.json',
                },
                {
                    description = 'Drupal Layouts',
                    fileMatch = {
                        '*.layouts.yml',
                    },
                    url = 'https://www.schemastore.org/drupal-layouts.json',
                },
                {
                    description = 'Drupal Libraries',
                    fileMatch = {
                        '*.libraries.yml',
                    },
                    url = 'https://www.schemastore.org/drupal-libraries.json',
                },
                {
                    description = 'Drupal Links Action',
                    fileMatch = { '*.links.action.yml' },
                    url = 'https://www.schemastore.org/drupal-links-action.json',
                },
                {
                    description = 'Drupal Links Contextual',
                    fileMatch = { '*.links.contextual.yml' },
                    url = 'https://www.schemastore.org/drupal-links-contextual.json',
                },
                {
                    description = 'Drupal Links Menu',
                    fileMatch = { '*.links.menu.yml' },
                    url = 'https://www.schemastore.org/drupal-links-menu.json',
                },
                {
                    description = 'Drupal Links Task',
                    fileMatch = { '*.links.task.yml' },
                    url = 'https://www.schemastore.org/drupal-links-task.json',
                },
                {
                    description = 'Drupal Migration',
                    fileMatch = { '*.migration.*.yml', '**/migrations/*.yml' },
                    url = 'https://www.schemastore.org/drupal-migration.json',
                },
                {
                    description = 'Drupal Permissions',
                    fileMatch = {
                        '*.permissions.yml',
                    },
                    url = 'https://www.schemastore.org/drupal-permissions.json',
                },
                {
                    description = 'Drupal Recipe',
                    fileMatch = {
                        'drupal-recipe.yml',
                        'drupal-recipe.yaml',
                    },
                    url = 'https://www.schemastore.org/drupal-recipe.json',
                },
                {
                    description = 'Drupal Routing',
                    fileMatch = { '*.routing.yml' },
                    url = 'https://www.schemastore.org/drupal-routing.json',
                },
                {
                    description = 'Drupal Config schema',
                    fileMatch = { '**/config/schema/*.schema.yml' },
                    url = 'https://www.schemastore.org/drupal-config.json',
                },
                {
                    description = 'Drupal Services',
                    fileMatch = {
                        '*.services.yml',
                    },
                    url = 'https://www.schemastore.org/drupal-services.json',
                },
                {
                    description = 'ESLint config',
                    fileMatch = {
                        '.eslintrc',
                        '.eslintrc.json',
                        '.eslintrc.yml',
                        '.eslintrc.yaml',
                    },
                    url = 'https://json.schemastore.org/eslintrc.json',
                },
                {
                    description = 'F-Droid Data app metadata files',
                    fileMatch = {
                        '**/metadata/*.yml',
                    },
                    url = 'https://gitlab.com/fdroid/fdroiddata/-/raw/master/schemas/metadata.json',
                },
                {
                    description = 'Firebase configuration',
                    fileMatch = {
                        'firebase.json',
                        'firebase.jsonc',
                    },
                    url = 'https://raw.githubusercontent.com/firebase/firebase-tools/master/schema/firebase-config.json',
                },
                {
                    description = 'FlexGet config file',
                    fileMatch = {
                        '**/.flexget/config.yml',
                        '**/flexget/config.yml',
                    },
                    url = 'https://github.com/Flexget/Flexget/releases/latest/download/flexget-config.schema.json',
                },
                {
                    description = 'Gemini CLI settings',
                    fileMatch = {
                        '**/.gemini/settings.json',
                        '**/.gemini/settings.jsonc',
                        '**/gemini-cli/settings.json',
                        '**/gemini-cli/settings.jsonc',
                        '**/GeminiCli/settings.json',
                        '**/GeminiCli/settings.jsonc',
                    },
                    url = '"https://raw.githubusercontent.com/google-gemini/gemini-cli/refs/heads/main/schemas/settings.schema.json',
                },
                {
                    description = 'Google Cloud Workflows configuration file',
                    fileMatch = {
                        'workflows.json',
                        'workflows.yaml',
                        'workflows.yml',
                        '*.workflows.json',
                        '*.workflows.yaml',
                        '*.workflows.yml',
                    },
                    url = 'https://www.schemastore.org/workflows.json',
                },
                {
                    description = 'Helm Chart.yaml',
                    fileMatch = {
                        'Chart.yaml',
                    },
                    url = 'https://www.schemastore.org/chart.json',
                },
                {
                    description = 'Helm Chart.lock',
                    fileMatch = {
                        'Chart.lock',
                    },
                    url = 'https://www.schemastore.org/chart-lock.json',
                },
                {
                    description = 'Helm Unittest Test Suite',
                    fileMatch = {
                        '**/charts/*/tests/*.yaml',
                    },
                    url = 'https://raw.githubusercontent.com/helm-unittest/helm-unittest/refs/heads/main/schema/helm-testsuite.json',
                },
                {
                    description = 'latexindent configuration',
                    fileMatch = {
                        'latexindent.yaml',
                        '.latexindent.yaml',
                    },
                    url = 'https://github.com/cmhughes/latexindent.pl/raw/main/documentation/latexindent-yaml-schema.json',
                },
                {
                    description = 'browser.i18n messages.json translation file',
                    fileMatch = { 'messages.json' },
                    url = 'https://www.schemastore.org/browser.i18n.json',
                },
                {
                    description = 'package.json',
                    fileMatch = {
                        'package.json',
                        'package.jsonc',
                    },
                    url = 'https://json.schemastore.org/package.json',
                },
                {
                    description = 'Prettier',
                    fileMatch = {
                        '.prettierrc',
                        '.prettierrc.json',
                    },
                    url = 'https://json.schemastore.org/prettierrc',
                },
                {
                    description = 'Poetry',
                    fileMatch = {
                        'pyproject.poetry.json',
                    },
                    url = 'https://json.schemastore.org/pyproject.json',
                },
                {
                    name = '.remarkrc',
                    description = 'A remark configuration file',
                    fileMatch = {
                        '.remarkrc',
                        '.remarkrc.json',
                        '.remarkrc.jsonc',
                        '.remarkrc.yaml',
                        '.remarkrc.yml',
                    },
                    url = 'https://www.schemastore.org/remarkrc.json',
                },
                {
                    name = 'Replit config',
                    description = 'replit.com, a cloud IDE and code runner',
                    fileMatch = {
                        'replit.toml',
                    },
                    url = 'https://www.schemastore.org/replit.json',
                },
                {
                    name = 'Rubocop',
                    description = 'A Ruby code style checker (linter) and formatter',
                    fileMatch = {
                        '*.rubocop.yml',
                    },
                    url = 'https://www.rubyschema.org/rubocop.json',
                },
                {
                    name = 'Ruff',
                    description = 'Ruff, a fast Python linter',
                    fileMatch = {
                        'ruff.toml',
                        '.ruff.toml',
                    },
                    url = 'https://www.schemastore.org/ruff.json',
                },
                {
                    name = 'Rust Project',
                    description = 'non-Cargo based Rust projects',
                    fileMatch = {
                        'rust-project.json',
                        'rust-project.jsonc',
                    },
                    url = 'https://www.schemastore.org/rust-project.json',
                },
                {
                    description = 'tsconfig',
                    fileMatch = {
                        'tsconfig.json',
                        'tsconfig.*.json',
                    },
                    url = 'https://json.schemastore.org/tsconfig.json',
                },
                {
                    name = 'uv',
                    description = 'uv, a fast Python package installer',
                    fileMatch = {
                        'uv.toml',
                    },
                    url = 'https://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/uv.json',
                },
                {
                    description = 'vcpkg manifest file',
                    fileMatch = {
                        'vcpkg.json',
                        'vcpkg.jsonc',
                    },
                    url = 'https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json',
                },
                {
                    description = 'vcpkg configuration file',
                    fileMatch = {
                        'vcpkg-configuration.json',
                        'vcpkg-configuration.jsonc',
                    },
                    url = 'https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg-configuration.schema.json',
                },
                {
                    description = 'Vercel configuration file',
                    fileMatch = { 'vercel.json' },
                    url = 'https://openapi.vercel.sh/vercel.json',
                },
                {
                    description = 'VSCode Code Snippets',
                    fileMatch = {
                        '*.code-snippets',
                    },
                    url = 'https://raw.githubusercontent.com/Yash-Singh1/vscode-snippets-json-schema/main/schema.json',
                },
                {
                    description = 'Vulkan Layers',
                    url = 'https://schema.khronos.org/vulkan/profiles-0.8-latest.json',
                    fileMatch = {
                        'VP_*.json',
                        'VP_*.jsonc',
                        '*vulkan_profile*.json',
                        '*vulkan_profile*.jsonc',
                        'profiles/*.json',
                    },
                },
                {
                    description = 'Zlint',
                    fileMatch = {
                        'zlint.json',
                        'zlint.jsonc',
                    },
                    url = 'https://raw.githubusercontent.com/DonIsaac/zlint/refs/heads/main/zlint.schema.json',
                },
            },
        },
    },
    validate = {
        enable = true,
    },
}