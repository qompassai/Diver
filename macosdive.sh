#!/usr/bin/env bash

set -e

function install_macos {
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    echo -e "Installing dependencies for macOS..."

    brew install openresty node python ruby rustup jq neovim

    rustup install stable
    pip3 install --user jupyter jupyterlab numpy pandas matplotlib scikit-learn torch torchvision torchaudio transformers datasets accelerate

    npm install -g neovim typescript typescript-language-server pyright bash-language-server vscode-langservers-extracted

    sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

    rustup component add rls rust-analysis rust-src
    cargo install ripgrep fd-find

    brew install lua-language-server

    pip3 install --user tensorboard optuna ray[tune] mlflow

    brew install pandoc
    npm install -g markdownlint-cli
    npm install -g prettier
    pip3 install --user mkdocs
    pip3 install --user pymdown-extensions
    pip3 install --user jupyter-book
    brew install mermaid-cli

    pip3 install --user grip

    brew install mdl

    echo "All dependencies have been installed successfully for macOS!"

    echo "Please note: You may need to manually configure Neovim and install plugins."
    echo "For Jupyter Lab extensions, you can install them using: jupyter labextension install <extension-name>"
    echo "For Markdown preview in Neovim, consider installing a plugin like 'iamcco/markdown-preview.nvim'"
}

install_macos
