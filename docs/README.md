<!-- /qompassai/Diver/docs/README.md -->
<!-- Qompass AI Diver Docs -->
<!-- Copyright (C) 2025 Qompass AI, All rights reserved -->
<!-- ---------------------------------------- -->

**Qompass Diver** was inspired by the great folks who made [NvChad](https://github.com/NvChad/NvChad). The intent of Diver is to build on the original configuration framework to provide an even more powerful, customizable, and user-friendly experience that bridges the skills gap left by education and industry. Qompass Diver enhances the flexibility of the original project while focusing on AI, cloud integrations, education, and developer productivity.

## Features
                                                                                                                                                                 Qompass Diver builds upon the solid foundation of NvChad, offering the following enhancements:

### AI Integration

- **Hugging Face Transformers**: Provides support for machine learning workflows with integration into Hugging Face transformers.
- **CUDA Support**: Tools and integrations for CUDA-based AI development, helping you leverage your GPU for machine learning tasks.
- ** Public Source AI integration**: We recommend pairing Diver with our neovim plugin Rose.nvim A plugin for safe, secure, and trustworthy AI-pair programming. We also include other great AI plugins like Avante and Supermaven

### Cloud Development

- **Remote Editing**: Allows seamless editing of files over SSH and remote machines using plugins like distant.lua, sshfs.lua, and more.
- **GPG & SSH Management**: Manage GPG and SSH keys effortlessly within Neovim for secure remote development environments.                                                                                                                                                                                                        ### Educational Tools
- **nvim-be-good**: Helps users practice and improve their Neovim proficiency with gamified learning tools.
- **Twilight**: A focus mode plugin that dims inactive portions of code to keep you concentrated on your current task.

### Developer Productivity                                                                                                                                                                                                                                                                                                        - **Jupyter Integration**: Enables running Jupyter notebooks inside Neovim, streamlining data science and development workflows.                                 - **Markdown to PDF Conversion**: Quickly convert Markdown documents into PDF files without leaving Neovim.
- **Completions and LSP**: Enhanced autocompletion and language server configurations with completion.lua and nvim-lsp.lua, supporting multiple languages and tools.
- **Debugging Tools**: Integrated debugging support using the Debug Adapter Protocol (DAP) and additional utilities.
                                                                                                                                                                 ### Enhanced UI and UX                                                                                                                                                                                                                                                                                                            - **Telescope Themes**: Easily toggle between themes via telescope integrated with transparent backgrounds
- **Lualine Integration**: Enhanced status line management with lualine.lua for better customization and UI experience.
- **Gitsigns**: Visual indicators for Git changes in the gutter for quick code reviews and version control management.

### Developer Tools
- **Rust Development**: Rust-specific configurations with rustaceanvim.lua to make Rust development seamless.
- **Treesitter**: Robust syntax highlighting and code parsing powered by treesitter.lua, improving the Neovim editing experience.
- **Telescope Fuzzy Finder**: Quick file and buffer navigation with telescope.lua, providing a fast way to access your project.

## Getting Started

### Install Dependencies before you start your dive

To set up Diver, you will first need to install the necessary dependencies using the provided `mac/arch/ubuntu/windowsdive.sh` script to simplify getting your system ready to dive.

- MacOS users can get the necessary core packages via `macosdive.sh` after cloning Diver locally

```sh
chmod +x macosdive.sh
./macosdive.sh
```

- Arch divers can get the necessary core packages via `archdive.sh` after cloning Diver locally

```sh
chmod +x archdive.sh
./archdive.sh
```

- Ubuntu/Debian divers can get the necessary core packages via `ubuntudive.sh` after cloning Diver locally

```sh
chmod +x ubuntudive.sh
./ubuntudive.sh
```

- Microsoft divers can get the necessary core packages via `windowsdive.sh` after cloning Diver locally

```sh
chmod +x windowsdive.sh
./windowsdive.sh
```

### Clone the Repository

After installing the dependencies, you can clone the Qompass Diver repository and set up Neovim:

```bash
# Clone the repository to your Neovim configuration folder
git clone https://github.com/qompassai/Diver ~/.config/nvim
```

- `gh repo clone qompassai/Diver ~/.config/nvim ` if you're a `real one` as the Zoomers say.

Once the repository is cloned, start Neovim and Qompass Diver will be ready for you to use.

### Final Steps

Launch Diver by starting Neovim:

```bash
nvim
```

Qompass Diver will automatically set up and load the required plugins for a streamlined experience
whether you're new or a seasoned pro.

And unlike other folks in the AI space, we will `NEVER` collect data on your use.

# How to stay updated

To get updates once this on your computer, you have two options:

1. [**Using HTTPS (Most Common)**](#using-https-most-common)
2. [**Using SSH (Advanced)**](#using-ssh-advanced)

- **Either** option requires[git](#how-to-install-git) to be installed:

### Using HTTPS (Most Common)

This option is best if:

    * You’re new to GitHub
    * You like to keep things simple.
    * You haven't set up SSH/GPG keys for Github.
    * You don't have the Github CLI

- MacOS | Linux | Microsoft WSL

```bash
git clone --depth 1 https://github.com/qompassai/Equator.git
git remote add upstream https://github.com/qompassai/Equator.git
git fetch upstream
git checkout main
git merge upstream/main
```

Note: You only need to run the clone command **once**. After that, go to [3. Getting Updates](#getting-updates) to keep your local repository up-to-date.

2. **Using SSH(Advanced)**:

-  MacOS | Linux | Microsoft WSL **with** [GitHub CLI (gh)](https://github.com/cli/cli#installation)

```bash
gh repo clone qompassai/Equator
git remote add upstream https://github.com/qompassai/Equator.git
git fetch upstream
git checkout main
git merge upstream/main
```

This option is best if you:

    * are not new to Github
    * You want to add a new technical skill
    * You're comfortable with the terminal/CLI, or want to be
    * You have SSH/GPG set up
    * You're

Note: You only need to run the clone command **once**. After that, go to [3. Getting Updates](#getting-updates) to keep your local repository up-to-date.

3. Getting updates

- **After** cloning locally, use the following snippet below to get the latest updates:

- MacOS | Linux | Microsoft WSL

- Option 1:
**This will **overwrite** any local changes you've made**

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

-Option 2:
**To keep your local changes and still get the updates**

```bash
git stash
git fetch upstream
git checkout main
git merge upstream/main
git stash pop
```


### To Uninstall

```sh
# Linux / MacOS (unix)
rm -rf ~/.config/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.local/share/nvim

# Flatpak (linux)
rm -rf ~/.var/app/io.neovim.nvim/config/nvim
rm -rf ~/.var/app/io.neovim.nvim/data/nvim
rm -rf ~/.var/app/io.neovim.nvim/.local/state/nvim

# Windows CMD
rd -r ~\AppData\Local\nvim
rd -r ~\AppData\Local\nvim-data

# Windows PowerShell
rm -Force ~\AppData\Local\nvim
rm -Force ~\AppData\Local\nvim-data

```

</blockquote>
</details>
