# /qompassai/Diver/flake.nix
# ---------------------------------------
# Copyright (C) 2025 Qompass AI, All rights reserved
{
  description = "Qompass AI Diver - Reproducible Neovim config";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, flake-utils, neovim-nightly-overlay, ... }:
    flake-utils.lib.eachSystem [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ] (system:
      let
        overlays = [ neovim-nightly-overlay.overlays.default ];
        pkgs = import nixpkgs {
          inherit system;
          overlays = overlays;
        };

        diver-nvim = pkgs.neovim-nightly.override {
          withNodeJs = true;
          withPython3 = true;
          withRuby = false;

          configure = {
            customRC = "";
            packages.myPlugins = with pkgs.vimPlugins; [
              LuaSnip
              SchemaStore-nvim
              cmp-digraphs
              coq.artifacts
              coq.thirdparty
              coq_nvim
              cord-nvim
              crates-nvim
              dressing-nvim
              friendly-snippets
              fzf-lua
              github-nvim-theme
              gruvbox-material
              guess-indent-nvim
              image-nvim
              jupynium-nvim
              jupytext-nvim
              lazy-nvim
              lazydev-nvim
              LazyVim
              legendary-nvim
              live-preview-nvim
              lualine-nvim
              luarocks
              mason-lspconfig-nvim
              mason-nvim
              mason-tool-installer-nvim
              material-nvim
              mini-ai
              molten-nvim
              nabla-nvim
              neo-tree-nvim
              neoconf-nvim
              nightfox-nvim
              noice-nvim
              none-ls-autoload-nvim
              none-ls-extras-nvim
              none-ls-jsonlint-nvim
              none-ls-luacheck-nvim
              none-ls-nvim
              none-ls-shellcheck-nvim
              nord-nvim
              nui-nvim
              nvim
              nvim-cmp
              nvim-colorizer-lua
              nvim-dap
              nvim-dap-python
              nvim-dap-ui
              nvim-dap-view
              nvim-dap-vscode-js
              nvim-jupyter
              nvim-lspconfig
              nvim-notify
              nvim-treesitter
              nvim-web-devicons
              onedark-nvim
              onedarkpro-nvim
              otter-nvim
              plenary-nvim
              quarto-nvim
              remote-nvim-nvim
              schemastore-nvim
              sqlite-lua
              telescope-nvim
              telescope-zoxide
              tokyonight-nvim
              transparent-nvim
              trouble-nvim
              typescript-nvim
              typst-preview-nvim
              venv-selector-nvim
              vim-dadbod-completion
              vim-gnupg
              vim-slime
              which-key-nvim
            ];
          };
        };
      in {
        packages.default = diver-nvim;

        apps.default = flake-utils.lib.mkApp {
          drv = diver-nvim;
        };

        devShells.default = pkgs.mkShell {
          name = "diver-shell";
          buildInputs = with pkgs; [
            diver-nvim
            fd
            fzf
            gcc
            go
            lua-language-server
            nodejs
            php
            phpPackages.composer
            poetry
            python3
            ripgrep
            rust-analyzer
            stylua
          ];

          shellHook = ''
            echo "🌊 Welcome to Diver! Run 'nvim' to launch."
          '';
        };
      });
}

