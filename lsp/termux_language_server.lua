-- /qompassai/Diver/lsp/termux_language_server.lua
-- Qompass AI Termux Language Server LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config["termux_language_server"] = {
  cmd = {
    "termux-language-server",
  },
  filetypes = {
    "ebuild",
    "eclass",
    "termux-build",
    "termux-subpackage",
    "pkgbuild",
    "pkgbuild-install",
    "makepkg-conf",
    "portage-make-conf",
    "portage-color-map",
    "devscripts-conf",
    "zsh-mdd",
  },
  root_markers = {
    ".git",
    ".hg",
    ".svn",
    "PKGBUILD",
    "build.sh",
    ".SRCINFO",
    "nvcheck.toml",
  },
  settings = {
    termux = {
      diagnostics = {
        enable = true,
      },
      formatting = {
        enable = true,
      },
      links = {
        enable = true,
      },
      completion = {
        enable = true,
      },
      codeAction = {
        enable = true,
      },
    },
  },
}
