# Qompass Diver for Neovim

**Qompass Diver** was inspired by the great folks who made [NvChad](https://github.com/NvChad/NvChad). The intent of Diver is to build on the original configuration framework to provide an even more powerful, customizable, and user-friendly experience that bridges the skills gap left by education and industry. Qompass Diver enhances the flexibility of the original project while focusing on AI, cloud integrations, education, and developer productivity.

## Features

Qompass Diver builds upon the solid foundation of NvChad, offering the following enhancements:

### AI Integration
- **Hugging Face Transformers**: Provides support for machine learning workflows with integration into Hugging Face transformers.
- **CUDA Support**: Tools and integrations for CUDA-based AI development, helping you leverage your GPU for machine learning tasks.
- **Ollama integration**: A plugin that provides AI-assisted code generation capabilities, integrating seamlessly with Neovim for improved productivity.
- **Open-Source Cursor via Avante**: Enhances AI-driven workflows, offering advanced completions and intelligent suggestions within Neovim.

### Cloud Development
- **Remote Editing**: Allows seamless editing of files over SSH and remote machines using plugins like distant.lua, sshfs.lua, and more.
- **GPG & SSH Management**: Manage GPG and SSH keys effortlessly within Neovim for secure remote development environments.

### Educational Tools
- **nvim-be-good**: Helps users practice and improve their Neovim proficiency with gamified learning tools.
- **Twilight**: A focus mode plugin that dims inactive portions of code to keep you concentrated on your current task.

### Developer Productivity
- **Jupyter Integration**: Enables running Jupyter notebooks inside Neovim, streamlining data science and development workflows.
- **Markdown to PDF Conversion**: Quickly convert Markdown documents into PDF files without leaving Neovim.
- **Completions and LSP**: Enhanced autocompletion and language server configurations with completion.lua and nvim-lsp.lua, supporting multiple languages and tools.
- **Debugging Tools**: Integrated debugging support using the Debug Adapter Protocol (DAP) and additional utilities.

### Enhanced UI and UX
- **Telescope Themes**: Easily toggle between themes via telescope integrated with transparent backgrounds
- **Lualine Integration**: Enhanced status line management with lualine.lua for better customization and UI experience.
- **Gitsigns**: Visual indicators for Git changes in the gutter for quick code reviews and version control management.

### Developer Tools
- **Rust Development**: Rust-specific configurations with rustaceanvim.lua to make Rust development seamless.
- **Treesitter**: Robust syntax highlighting and code parsing powered by treesitter.lua, improving the Neovim editing experience.
- **Telescope Fuzzy Finder**: Quick file and buffer navigation with telescope.lua, providing a fast way to access your project.

## Getting Started

### Install Dependencies with diver.sh

To set up Qompass Diver, you will first need to install the necessary dependencies using the provided `diver.sh` script based on your OS. This script automatically detects your operating system and installs the required tools. 


### Clone the Repository
After installing the dependencies, you can clone the Qompass Diver repository and set up Neovim:

```bash
# Clone the repository to your Neovim configuration folder
git clone https://github.com/qompassai/Diver ~/.config/nvim
```

Once the repository is cloned, start Neovim and Qompass Diver will be ready for you to use.

### Final Steps
Launch Neovim:
```bash
nvim
```
Qompass Diver will automatically set up and load the required plugins for a streamlined coding experience whether you're new or a seasoned pro. 

And unlike other folks in the AI space, we will NEVER collect data on your use.


## Dual-License Notice
This repository and all applications within it are dual-licensed under the terms of the [Qompass Commercial Distribution Agreement (CDA)](LICENSE) and [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE-AGPL) licenses.

## What a Dual-License means

### Protection for Vulnerable Populations

The dual licensing aims to address the cybersecurity gap that disproportionately affects underserved populations. As highlighted by [recent attacks][1], low-income residents, seniors, and foreign language speakers face higher-than-average risks of being victims of cyber attacks. By offering both open-source and commercial licensing options, we encourage the development of cybersecurity solutions that can reach these vulnerable groups while also enabling sustainable development and support.

### Preventing Malicious Use

The AGPL-3.0 license ensures that any modifications to the software remain open source, preventing bad actors from creating closed-source variants that could be used for exploitation. This is especially crucial given the rising threats to vulnerable communities, including children in educational settings. The attack on Minneapolis Public Schools, which resulted in the leak of 300,000 files and a $1 million ransom demand, highlights the importance of transparency and security ([source][5]).

### Addressing Cybersecurity in Critical Sectors

The commercial license option allows for tailored solutions in critical sectors such as healthcare, which has seen significant impacts from cyberattacks. For example, the recent [Change Healthcare attack][2] affected millions of Americans and caused widespread disruption for hospitals and other providers.

### Supporting Cybersecurity Awareness

The dual licensing model supports initiatives like [CISA's efforts to improve cybersecurity awareness][3] in "target rich" sectors, including K-12 education. By allowing both open-source and commercial use, we aim to facilitate the development of tools that support these critical awareness and protection efforts.

### Bridging the Digital Divide

Research shows that socioeconomic and digital inequalities significantly impact cybersecurity awareness and practices ([source][4]). Our dual licensing approach aims to address this by allowing both free, open-source solutions and commercially supported options that can be tailored to specific needs and contexts.

### Recent Cybersecurity Attacks

Recent attacks underscore the importance of robust cybersecurity measures:

- The [Change Healthcare cyberattack in February 2024][2] affected millions of Americans and caused significant disruption to healthcare providers.
- In the education sector, [Minneapolis Public Schools][5] experienced an attack that leaked 300,000 files and led to a $1 million ransom demand.

### Conclusion

By offering both open-source and commercial licensing options, we strive to create a balance that promotes innovation and accessibility while also providing the necessary resources and flexibility to address the complex cybersecurity challenges faced by vulnerable populations and critical infrastructure sectors.

[1]: https://www.whitehouse.gov/briefing-room/statements-releases/2024/10/02/international-counter-ransomware-initiative-2024-joint-statement/ "International Counter Ransomware Initiative 2024 Joint Statement"
[2]: https://www.chiefhealthcareexecutive.com/view/the-top-10-health-data-breaches-of-the-first-half-of-2024 "The Top 10 Health Data Breaches of the First Half of 2024"
[3]: https://www.cisa.gov/K12Cybersecurity "CISA's K-12 Cybersecurity Initiatives"
[4]: https://thejournal.com/Articles/2024/07/24/Todays-K12-Cybersecurity-Threats-And-How-to-Combat-Them.aspx "Today's K-12 Cybersecurity Threats and How to Combat Them"
[5]: https://www.cisa.gov/protecting-our-future-cybersecurity-k-12 "Protecting Our Future: Cybersecurity for K-12"
"

