-- #################################################################
-- ~/.config/nvim/lua/formatters/catalog.lua
-- Trusted formatter package metadata and installation recipes
-- #################################################################
---@source https://github.com/qompassai/diver
local fs = vim.fs
local root = fs.joinpath(vim.fn.stdpath('data'), 'formatter-toolchains')

local M = {
    root = root,
    paths = {
        fs.joinpath(root, 'bin'),
        fs.joinpath(root, 'cargo', 'bin'),
        fs.joinpath(root, 'composer', 'vendor', 'bin'),
        fs.joinpath(root, 'dotnet-tools'),
        fs.joinpath(root, 'gems', 'bin'),
        fs.joinpath(root, 'node_modules', '.bin'),
        fs.joinpath(root, 'python', 'bin'),
    },
    entries = {},
}

local function github(repository)
    return {
        url = 'https://api.github.com/repos/' .. repository .. '/releases/latest',
        field = 'tag_name',
    }
end

local function cargo(name, crate, repository)
    M.entries[name] = {
        source = {
            url = 'https://crates.io/api/v1/crates/' .. crate,
            field = 'crate.max_stable_version',
        },
        probe = function(command)
            return { command, '--version' }
        end,
        url = 'https://github.com/' .. repository,
        install = function(version)
            return {
                argv = {
                    'cargo',
                    'install',
                    '--locked',
                    '--version',
                    version,
                    '--root',
                    fs.joinpath(root, 'cargo'),
                    crate,
                },
            }
        end,
    }
end

local function go_tool(name, module, package_path, version_args)
    M.entries[name] = {
        source = {
            url = 'https://proxy.golang.org/' .. module .. '/@latest',
            field = 'Version',
        },
        probe = function(command)
            if version_args then
                local argv = { command }
                vim.list_extend(argv, version_args)
                return argv
            end
            return { 'go', 'version', '-m', command }
        end,
        build_info = version_args == nil,
        url = 'https://pkg.go.dev/' .. package_path,
        install = function(version)
            return {
                argv = { 'go', 'install', package_path .. '@v' .. version },
                env = {
                    GOBIN = fs.joinpath(root, 'bin'),
                    GOTOOLCHAIN = 'local',
                },
            }
        end,
    }
end

local function npm_api(name, package_name, directory_name, pin)
    local prefix = fs.joinpath(vim.fn.stdpath('data'), 'formatters', directory_name)
    M.entries[name] = {
        private = true,
        pin = pin,
        manifest = fs.joinpath(prefix, 'node_modules', package_name, 'package.json'),
        source = {
            url = 'https://registry.npmjs.org/' .. package_name .. '/latest',
            field = 'version',
        },
        url = 'https://www.npmjs.com/package/' .. package_name,
        install = function(version)
            return {
                argv = {
                    'npm',
                    'install',
                    '--prefix',
                    prefix,
                    '--ignore-scripts',
                    '--no-audit',
                    '--no-fund',
                    '--save-exact',
                    package_name .. '@' .. version,
                },
            }
        end,
    }
end

cargo('alejandra', 'alejandra', 'kamadorueda/alejandra')
cargo('dioxus', 'dioxus-cli', 'DioxusLabs/dioxus')
cargo('stylua', 'stylua', 'JohnnyMorganz/StyLua')
cargo('shellharden', 'shellharden', 'anordal/shellharden')
cargo('efmt', 'efmt', 'sile/efmt')
cargo('hledger_fmt', 'hledger-fmt', 'mondeja/hledger-fmt')
cargo('nickel_format', 'nickel-lang-cli', 'tweag/nickel')
cargo('panache', 'panache', 'jolars/panache')
cargo('rumdl_fmt', 'rumdl', 'rvben/rumdl')
cargo('schemat', 'schemat', 'raviqqe/schemat')
cargo('sqruff', 'sqruff', 'quarylabs/sqruff')
cargo('taplo', 'taplo-cli', 'tamasfe/taplo')
cargo('tex_fmt', 'tex-fmt', 'wgunderwood/tex-fmt')
cargo('tombi', 'tombi', 'tombi-toml/tombi')
cargo('typstfmt', 'typstfmt', 'astrale-sharp/typstfmt')
cargo('typstyle', 'typstyle', 'Enter-tainer/typstyle')

go_tool('goimports', 'golang.org/x/tools', 'golang.org/x/tools/cmd/goimports')
go_tool('gofumpt', 'mvdan.cc/gofumpt', 'mvdan.cc/gofumpt', { '--version' })
go_tool('shfmt', 'mvdan.cc/sh/v3', 'mvdan.cc/sh/v3/cmd/shfmt', { '--version' })
go_tool('buildifier', 'github.com/bazelbuild/buildtools', 'github.com/bazelbuild/buildtools/buildifier')
go_tool('cue_fmt', 'cuelang.org/go', 'cuelang.org/go/cmd/cue')
go_tool('hclfmt', 'github.com/hashicorp/hcl', 'github.com/hashicorp/hcl/cmd/hclfmt')
go_tool('jsonnetfmt', 'github.com/google/go-jsonnet', 'github.com/google/go-jsonnet/cmd/jsonnetfmt')
go_tool('templ_fmt', 'github.com/a-h/templ', 'github.com/a-h/templ/cmd/templ')
go_tool('yamlfmt', 'github.com/google/yamlfmt', 'github.com/google/yamlfmt/cmd/yamlfmt')

npm_api('wgslfmt', '@wasm-fmt/wgslfmt', 'wgslfmt', '0.1.0')
npm_api('bibtex_tidy', 'bibtex-tidy', 'bibtex-tidy', '1.15.1')

--- Install a Python formatter with pip into the catalog-local prefix.
---@param name string module_sources key
---@param package string PyPI distribution name
local function pip(name, package)
    M.entries[name] = {
        source = {
            url = 'https://pypi.org/pypi/' .. package .. '/json',
            field = 'info.version',
        },
        probe = function(command)
            return { command, '--version' }
        end,
        url = 'https://pypi.org/project/' .. package .. '/',
        install = function(version)
            return {
                argv = {
                    'python3',
                    '-m',
                    'pip',
                    'install',
                    '--prefix',
                    fs.joinpath(root, 'python'),
                    package .. '==' .. version,
                },
            }
        end,
    }
end

--- Install a Ruby formatter with gem into the catalog-local gem home.
---@param name string module_sources key
---@param gem_name string RubyGems gem name
local function gem(name, gem_name)
    M.entries[name] = {
        source = {
            url = 'https://rubygems.org/api/v1/gems/' .. gem_name .. '.json',
            field = 'version',
        },
        probe = function(command)
            return { command, '--version' }
        end,
        url = 'https://rubygems.org/gems/' .. gem_name,
        install = function(version)
            return {
                argv = {
                    'gem',
                    'install',
                    '--install-dir',
                    fs.joinpath(root, 'gems'),
                    '--no-document',
                    gem_name,
                    '--version',
                    version,
                },
            }
        end,
    }
end

--- Install a PHP formatter with composer global require.
---@param name string module_sources key
---@param package string Packagist vendor/package name
---@param repository string GitHub owner/repo used for release metadata
local function composer_pkg(name, package, repository)
    M.entries[name] = {
        source = github(repository),
        probe = function(command)
            return { command, '--version' }
        end,
        url = 'https://packagist.org/packages/' .. package,
        install = function(version)
            return {
                argv = {
                    'composer',
                    'global',
                    'require',
                    '--no-interaction',
                    '--no-scripts',
                    '--no-plugins',
                    package .. ':' .. version,
                },
                env = {
                    COMPOSER_HOME = fs.joinpath(root, 'composer'),
                },
            }
        end,
    }
end

--- Install a .NET global tool into the catalog-local tool path.
---@param name string module_sources key
---@param package string dotnet tool package id
---@param repository string GitHub owner/repo used for release metadata
local function dotnet_tool(name, package, repository)
    local tool_path = fs.joinpath(root, 'dotnet-tools')
    M.entries[name] = {
        source = github(repository),
        probe = function(_)
            return { 'dotnet', 'tool', 'list', '--tool-path', tool_path }
        end,
        url = 'https://github.com/' .. repository,
        install = function(version)
            return {
                argv = {
                    'dotnet',
                    'tool',
                    'install',
                    '--tool-path',
                    tool_path,
                    package,
                    '--version',
                    version,
                },
            }
        end,
    }
end

--- Install an npm package into the shared catalog prefix.
--- Unlike npm_api, the binary is probed directly from PATH instead of
--- through node, so this only fits packages with a real bin entry.
---@param name string module_sources key
---@param package_name string npm package name
local function npm_bin(name, package_name)
    M.entries[name] = {
        source = {
            url = 'https://registry.npmjs.org/' .. package_name .. '/latest',
            field = 'version',
        },
        manifest = fs.joinpath(root, 'node_modules', package_name, 'package.json'),
        probe = function(command)
            return { command, '--version' }
        end,
        url = 'https://www.npmjs.com/package/' .. package_name,
        install = function(version)
            return {
                argv = {
                    'npm',
                    'install',
                    '--prefix',
                    root,
                    '--no-audit',
                    '--no-fund',
                    '--save-exact',
                    '--ignore-scripts',
                    package_name .. '@' .. version,
                },
            }
        end,
    }
end

pip('autopep8', 'autopep8')
pip('bean_format', 'beancount')
pip('black', 'black')
pip('blackd', 'black')
pip('cmake_format', 'cmake-format')
pip('djlint', 'djlint')
pip('docstrfmt', 'docstrfmt')
pip('fprettify', 'fprettify')
pip('gdformat', 'gdformat')
pip('mbake', 'mbake')
pip('mdformat', 'mdformat')
pip('mh_style', 'miss_hit')
pip('nginxfmt', 'nginxfmt')
pip('robotidy', 'robotframework-tidy')
pip('ruff_format', 'ruff')
pip('snakefmt', 'snakefmt')
pip('sqlfluff', 'sqlfluff')
pip('vsg', 'vsg')
pip('xmlformat', 'xmlformatter')
pip('yapf', 'yapf')

gem('cookstyle', 'cookstyle')
gem('erb_formatter', 'erb-formatter')
gem('htmlbeautify', 'htmlbeautifier')
gem('puppet_lint_fix', 'puppet-lint')
gem('rubocop', 'rubocop')
gem('standardrb', 'standard')

composer_pkg('phpcbf', 'squizlabs/php_codesniffer', 'squizlabs/php_codesniffer')
composer_pkg('pint', 'laravel/pint', 'laravel/pint')
composer_pkg('twig_cs_fixer', 'vincentlanglet/twig-cs-fixer', 'vincentlanglet/twig-cs-fixer')

dotnet_tool('csharpier', 'csharpier', 'belav/csharpier')
dotnet_tool('fantomas', 'fantomas', 'fsprojects/fantomas')

-- dprint and elm-format ship their binaries through npm install scripts,
-- which this catalog disables; both are covered by bespoke entries below.
npm_bin('biome', '@biomejs/biome')
npm_bin('css-beautify', 'js-beautify')
npm_bin('kulala_fmt', '@mistweaverco/kulala-fmt')
npm_bin('prettier', 'prettier')
npm_bin('prettierd', '@fsouza/prettierd')
npm_bin('purs_tidy', 'purs-tidy')
npm_bin('refmt', 'rescript')
npm_bin('rescript_format', 'rescript')
npm_bin('sql-formatter', 'sql-formatter')

M.entries.clang_format = {
    source = github('llvm/llvm-project'),
    probe = function(command)
        return { command, '--version' }
    end,
    arch_package = 'clang',
    url = 'https://clang.llvm.org/docs/ClangFormat.html',
    instructions = 'Install clang-format through your LLVM package manager.',
}

M.entries.phpcsfixer = {
    source = github('PHP-CS-Fixer/PHP-CS-Fixer'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/PHP-CS-Fixer/PHP-CS-Fixer',
    install = function(version)
        return {
            argv = {
                'composer',
                'global',
                'require',
                '--no-interaction',
                '--no-scripts',
                '--no-plugins',
                'friendsofphp/php-cs-fixer:' .. version,
            },
            env = {
                COMPOSER_HOME = fs.joinpath(root, 'composer'),
            },
        }
    end,
}

local ktfmt_root = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'ktfmt')
local ktfmt_jar = fs.joinpath(ktfmt_root, 'ktfmt-0.64-with-dependencies.jar')

M.entries.ktfmt = {
    private = true,
    pin = '0.64',
    files = {
        ktfmt_jar,
        fs.joinpath(ktfmt_root, 'KtfmtStdin.java'),
    },
    source = github('Kotlin/ktfmt'),
    probe = function(command)
        return { command, '-jar', ktfmt_jar, '--version' }
    end,
    url = 'https://github.com/Kotlin/ktfmt/releases/tag/v0.64',
    instructions = 'Use the pinned ktfmt installation instructions supplied '
        .. 'with your adapter. Both the JAR and KtfmtStdin.java are required. '
        .. 'Updating the JAR alone may break the adapter.',
}

M.entries.aiken_fmt = {
    source = github('aiken-lang/aiken'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/aiken-lang/aiken',
    instructions = 'Install the aiken binary from GitHub releases; aiken fmt is included.',
}

M.entries.air = {
    source = github('posit-dev/air'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/posit-dev/air',
    instructions = 'Install the air binary from GitHub releases.',
}

M.entries.bicep_format = {
    source = github('Azure/bicep'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/Azure/bicep',
    instructions = 'Install the bicep CLI from GitHub releases; bicep format is included.',
}

M.entries.brittany = {
    source = github('lspitzner/brittany'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/lspitzner/brittany',
    instructions = 'Install brittany from GitHub releases or with cabal install brittany.',
}

M.entries.buf_format = {
    source = github('bufbuild/buf'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/bufbuild/buf',
    instructions = 'Install the buf CLI from GitHub releases; buf format is included.',
}

M.entries.cabal_fmt = {
    source = github('phadej/cabal-fmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/phadej/cabal-fmt',
    instructions = 'Install cabal-fmt with cabal install cabal-fmt.',
}

M.entries.crystal_format = {
    source = github('crystal-lang/crystal'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/crystal-lang/crystal',
    instructions = 'Install the Crystal compiler from GitHub releases; ' .. 'crystal tool format is included.',
}

M.entries.dart_format = {
    source = github('dart-lang/sdk'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/dart-lang/sdk',
    instructions = 'Install the Dart SDK; dart format is included.',
}

M.entries.deno_fmt = {
    source = github('denoland/deno'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/denoland/deno',
    instructions = 'Install Deno; deno fmt is included.',
}

M.entries.dfmt = {
    source = github('dlang-community/dfmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/dlang-community/dfmt',
    instructions = 'Install the dfmt DUB package with dub fetch dfmt, or build it from source.',
}

M.entries.dhall_format = {
    source = github('dhall-lang/dhall-haskell'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/dhall-lang/dhall-haskell',
    instructions = 'Install the dhall binary from GitHub releases; dhall format is included.',
}

M.entries.dprint = {
    source = github('dprint/dprint'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/dprint/dprint',
    instructions = 'Install dprint from GitHub releases.',
}

M.entries.elm_format = {
    source = github('avh4/elm-format'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/avh4/elm-format',
    instructions = 'Install elm-format from GitHub releases.',
}

M.entries.erlfmt = {
    source = github('WhatsApp/erlfmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/WhatsApp/erlfmt',
    instructions = 'Download the erlfmt escript from GitHub releases.',
}

M.entries.findent = {
    source = github('wvermin/findent'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/wvermin/findent',
    instructions = 'Install findent from GitHub releases.',
}

M.entries.fish_indent = {
    source = github('fish-shell/fish-shell'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/fish-shell/fish-shell',
    instructions = 'Install the fish shell; fish_indent ships with it.',
}

M.entries.fnlfmt = {
    url = 'https://git.sr.ht/~technomancy/fnlfmt',
    instructions = 'Clone https://git.sr.ht/~technomancy/fnlfmt and run make install PREFIX=<dir> to install fnlfmt.',
}

M.entries.forge_fmt = {
    source = github('foundry-rs/foundry'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/foundry-rs/foundry',
    instructions = 'Install Foundry with foundryup; forge fmt is included.',
}

M.entries.fourmolu = {
    source = github('fourmolu/fourmolu'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/fourmolu/fourmolu',
    instructions = 'Download fourmolu from GitHub releases.',
}

M.entries.gleam_format = {
    source = github('gleam-lang/gleam'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/gleam-lang/gleam',
    instructions = 'Install the Gleam toolchain from GitHub releases; gleam format is included.',
}

M.entries.gofmt = {
    source = github('golang/go'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/golang/go',
    instructions = 'Install the Go toolchain; gofmt is included.',
}

M.entries.google_java_format = {
    source = github('google/google-java-format'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/google/google-java-format',
    instructions = 'Download the google-java-format all-deps JAR from GitHub releases.',
}

M.entries.grain_format = {
    source = github('grain-lang/grain'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/grain-lang/grain',
    instructions = 'Install the Grain compiler from GitHub releases; grain format is included.',
}

M.entries.janet_format = {
    source = github('janet-lang/spork'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/janet-lang/spork',
    instructions = 'Install the spork bundle with jpm (jpm install spork); '
        .. 'janet-format ships as spork/bin/janet-format.',
}

M.entries.jq = {
    source = github('jqlang/jq'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/jqlang/jq',
    instructions = 'Install jq from GitHub releases or your OS package manager.',
}

M.entries.just_fmt = {
    source = github('casey/just'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/casey/just',
    instructions = 'Install just from GitHub releases; just --fmt formats justfiles.',
}

M.entries.kcl_fmt = {
    source = github('kcl-lang/kcl'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/kcl-lang/kcl',
    instructions = 'Install the KCL CLI from GitHub releases; kcl fmt is included.',
}

M.entries.ktlint = {
    source = github('pinterest/ktlint'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/pinterest/ktlint',
    instructions = 'Download ktlint from GitHub releases.',
}

M.entries.latexindent = {
    url = 'https://ctan.org/pkg/latexindent',
    instructions = 'Install TeXLive, which provides latexindent.',
}

M.entries.mago_format = {
    source = github('carthage-software/mago'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/carthage-software/mago',
    instructions = 'Install mago from GitHub releases.',
}

M.entries.mix_format = {
    source = github('elixir-lang/elixir'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/elixir-lang/elixir',
    instructions = 'Install Elixir; mix format is included.',
}

M.entries.muon_fmt = {
    source = github('muon-build/muon'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/muon-build/muon',
    instructions = 'Install muon from GitHub releases; muon fmt is included.',
}

M.entries.nimpretty = {
    source = github('nim-lang/Nim'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/nim-lang/Nim',
    instructions = 'Install Nim with choosenim; nimpretty ships with the toolchain.',
}

M.entries.nixfmt = {
    source = github('NixOS/nixfmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/NixOS/nixfmt',
    instructions = 'Install nixfmt from GitHub releases or with nix profile install nixpkgs#nixfmt.',
}

M.entries.nomad_fmt = {
    source = github('hashicorp/nomad'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/hashicorp/nomad',
    instructions = 'Install Nomad; nomad fmt is included.',
}

M.entries.nufmt = {
    source = github('nushell/nufmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/nushell/nufmt',
    instructions = 'Install nufmt from GitHub releases.',
}

M.entries.ocamlformat = {
    source = github('ocaml-ppx/ocamlformat'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/ocaml-ppx/ocamlformat',
    instructions = 'Install ocamlformat with opam install ocamlformat.',
}

M.entries.opa_fmt = {
    source = github('open-policy-agent/opa'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/open-policy-agent/opa',
    instructions = 'Install the opa binary from GitHub releases; opa fmt is included.',
}

M.entries.ormolu = {
    source = github('tweag/ormolu'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/tweag/ormolu',
    instructions = 'Download ormolu from GitHub releases.',
}

M.entries.packer_fmt = {
    source = github('hashicorp/packer'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/hashicorp/packer',
    instructions = 'Install Packer; packer fmt is included.',
}

M.entries.perltidy = {
    source = {
        url = 'https://fastapi.metacpan.org/v1/release/Perl-Tidy',
        field = 'version',
    },
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://metacpan.org/dist/Perl-Tidy',
    instructions = 'Install Perl::Tidy from CPAN with cpanm Perl::Tidy.',
}

M.entries.pg_format = {
    source = github('darold/pgFormatter'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/darold/pgFormatter',
    instructions = 'Install pgFormatter from GitHub releases.',
}

M.entries.ptop = {
    url = 'https://www.freepascal.org/',
    instructions = 'Install Free Pascal, which provides ptop.',
}

M.entries.qmlformat = {
    url = 'https://doc.qt.io/qt-6/qtqml-tooling-qmlformat.html',
    instructions = 'Install Qt 6, which provides qmlformat.',
}

M.entries.raco_fmt = {
    source = github('racket/racket'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/racket/racket',
    instructions = 'Install Racket; raco fmt is included.',
}

M.entries.rubyfmt = {
    source = github('rubyfmt/rubyfmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/rubyfmt/rubyfmt',
    instructions = 'Install rubyfmt from GitHub releases.',
}

M.entries.rustfmt = {
    source = github('rust-lang/rustfmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/rust-lang/rustfmt',
    instructions = 'Install the rustfmt component with rustup component add rustfmt.',
}

M.entries.scalafmt = {
    source = github('scalameta/scalafmt'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/scalameta/scalafmt',
    instructions = 'Install scalafmt with cs install scalafmt, or download it from GitHub releases.',
}

M.entries.scarb_fmt = {
    source = github('software-mansion/scarb'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/software-mansion/scarb',
    instructions = 'Install Scarb from GitHub releases; scarb fmt is included.',
}

M.entries.styler = {
    source = {
        url = 'https://crandb.r-pkg.org/styler',
        field = 'Version',
    },
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://cran.r-project.org/package=styler',
    instructions = 'In R, run install.packages("styler").',
}

M.entries.superhtml = {
    source = github('kristoff-it/superhtml'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/kristoff-it/superhtml',
    instructions = 'Install superhtml from GitHub releases.',
}

M.entries.swift_format = {
    source = github('swiftlang/swift-format'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/swiftlang/swift-format',
    instructions = 'Build swift-format from source, or download it from GitHub releases.',
}

M.entries.swiftformat = {
    source = github('nicklockwood/SwiftFormat'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/nicklockwood/SwiftFormat',
    instructions = 'Install swiftformat from GitHub releases.',
}

M.entries.terraform_fmt = {
    source = github('hashicorp/terraform'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/hashicorp/terraform',
    instructions = 'Install Terraform; terraform fmt is included.',
}

M.entries.tofu_fmt = {
    source = github('opentofu/opentofu'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/opentofu/opentofu',
    instructions = 'Install OpenTofu from GitHub releases; tofu fmt is included.',
}

M.entries.uncrustify = {
    source = github('uncrustify/uncrustify'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/uncrustify/uncrustify',
    instructions = 'Install uncrustify from GitHub releases or your OS package manager.',
}

M.entries.v_fmt = {
    source = github('vlang/v'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/vlang/v',
    instructions = 'Install V from GitHub releases; v fmt is included.',
}

M.entries.verible_verilog_format = {
    source = github('chipsalliance/verible'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/chipsalliance/verible',
    instructions = 'Install Verible from GitHub releases; it provides verible-verilog-format.',
}

M.entries.xmllint = {
    url = 'https://gitlab.gnome.org/GNOME/libxml2',
    instructions = 'Install libxml2, which provides xmllint.',
}

M.entries.zig_fmt = {
    source = github('ziglang/zig'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/ziglang/zig',
    instructions = 'Install Zig from GitHub releases; zig fmt is included.',
}

M.entries.zprint = {
    source = github('kkinnear/zprint'),
    probe = function(command)
        return { command, '--version' }
    end,
    url = 'https://github.com/kkinnear/zprint',
    instructions = 'Install zprint from GitHub releases.',
}

---@param name string
---@param entry table
function M.register(name, entry)
    assert(name:match('^[%w_-]+$'), 'Invalid formatter name')
    assert(type(entry) == 'table', 'Metadata must be a table')
    M.entries[name] = entry
end

return M
