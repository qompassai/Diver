#!/usr/bin/env python3
# /qompassai/Diver/scripts/host.py
# Qompass AI Diver Python Host Script
# -----------------------------------
from pynvim import attach, plugin, command  # type: ignore[import]

nvim = attach("stdio")


@plugin
class PyHost:
    def __init__(self, nvim):
        self.nvim = nvim

    @command("PyHostHello", nargs="*", sync=True)
    def hello(self, args):
        """Echo a message from the Python RPC host."""
        msg = " ".join(args) if args else "Hello from Python RPC host"
        self.nvim.out_write(msg + "\n")

    @command("PyHostRuffFile", nargs="0", sync=True)
    def ruff_current_file(self, _args):
        """Run `ruff check` on the current file and populate quickfix."""
        fname = self.nvim.funcs.expand("%:p")
        if not fname:
            self.nvim.err_write("No file name for Ruff\n")
            return

        self.nvim.command(
            f"cgetexpr system('ruff check {fname} 2>&1') | copen"
        )

    @command("PyHostRuffProject", nargs="0", sync=True)
    def ruff_project(self, _args):
        """Run `ruff check .` for the current project and open quickfix."""
        cwd = self.nvim.funcs.getcwd()
        self.nvim.command(
            f"lcd {cwd} | cgetexpr system('ruff check . 2>&1') | copen"
        )


def main():
    nvim.run_loop(None, None)


if __name__ == "__main__":
    main()
