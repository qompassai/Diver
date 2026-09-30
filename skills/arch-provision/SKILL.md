---
name: arch-provision
description: "Provisions a fresh Arch Linux machine end-to-end: full system update, bootstraps the AUR helper, configures snapper BTRFS snapshots, enables multilib, installs the display manager and KDE Plasma, installs the NVIDIA driver, applies the curated package list from packages.yml across pacman/yay/flatpak/npm, and finishes with a reboot prompt. Use when Matt asks to set up a new arch machine, provision a workstation, run a fresh install of his packages, or bring a new Arch box up to his dotfiles standard."
license: Apache-2.0
compatibility: Arch Linux (x86_64) with sudo access. BTRFS filesystem is required for the snapper phase (verify before running it). NVIDIA driver phase applies only to machines with NVIDIA GPUs; skip it otherwise.
metadata:
  managers: pacman/yay/paru/flatpak/npm
  package_list: packages.yml
  prereq_fs: btrfs
  source_repo: dotfiles/arch
allowed-tools: Read Edit Bash
---

# arch-provision

Fresh-machine provisioning for Arch Linux, mirroring Matt's dotfiles
`arch/` install program. This skill drives the full sequence on a NEW
machine; it is **not** for routine system updates (that is a separate
skill — do not run `update.sh` logic here).

## Activation

<skill_resources>
</skill_resources>

- **Dedup rule:** never re-inject this skill when it is already in context
  for this session; it holds the whole program.
- **Subagent delegation: partial.** The multi-phase install (update through
  package list) is safe to delegate — it is long, sequential, and fail-fast.
  But the final reboot step must NOT be delegated: a subagent does not
  survive a reboot, and the post-reboot state must be verified by the owning
  session. Hand the parent agent the state of every phase so it can decide
  when to reboot.

## Hard prerequisites

Check these BEFORE touching anything else. Abort the phase they guard if
unmet — never work around them.

1. **Arch Linux.** Bail if `/etc/os-release` does not identify as Arch.
2. **BTRFS root for snapper.** Run before the snapper phase:
   `findmnt -no FSTYPE /` — must print `btrfs`. If it does not, skip
   snapper entirely (no config, no snapshot) and say so loudly.
3. **NVIDIA phase is conditional.** Run only when NVIDIA hardware is
   present (`lspci | grep -i nvidia` or `nvidia-smi` succeeds). On AMD,
   Intel, or headless machines, skip it.
4. **sudo access.** The whole program assumes an account that can sudo
   without babysitting; do not hard-code passwords.

## Phase 0 — Full system update (first, always)

```bash
sudo pacman -Syu --noconfirm
```

This is the only point in the program where a full upgrade happens. Every
later phase builds on the updated system.

## Phase 1 — Pacman tuning

Apply `ParallelDownloads = 5` to `/etc/pacman.conf`, inserted directly
after the `[options]` line, only if not already configured:

```bash
if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
  sudo sed -i '/\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
fi
```

## Phase 2 — Run the install scripts, in order, fail-fast

From the `arch/` directory of the dotfiles repo. Each script exits
non-zero on failure; **stop the program at the first failure** and report
which phase failed and what it printed.

1. `scripts/yay.sh` — bootstraps yay from the AUR: installs `git` and
   `base-devel` via pacman, clones `https://aur.archlinux.org/yay.git`
   shallow into `~/Downloads/yay`, runs `makepkg -si --noconfirm`, then
   removes the build directory. Idempotent: exits early if yay is already
   installed. (Note: yay is the bootstrap AUR helper; paru at
   `/usr/bin/paru` is Matt's everyday AUR helper and may be used for
   later AUR installs once it exists.)
2. `scripts/snapper.sh` — **BTRFS only** (see prerequisite 2). Installs
   `snapper snap-pac sudo base-devel`, creates the snapper config for the
   root filesystem (`snapper -c root create-config /`), installs
   `snapper-rollback` from the AUR, writes `/etc/snapper-rollback.conf`
   pointing at the root partition (`findmnt -n -o SOURCE /`), and takes
   an initial snapshot described as `backup: initial snapshot`.
   Idempotent: skips steps already done.
3. `scripts/sddm.sh` — installs and enables the SDDM display manager.
4. `scripts/kde.sh` — installs KDE Plasma.
5. `scripts/enable_multilib.sh` — backs up `/etc/pacman.conf` to
   `/etc/pacman.conf.bak.YYYY-MM-DD`, uncomments the `[multilib]` section
   and its `Include = /etc/pacman.d/mirrorlist` line, then runs
   `sudo pacman -Sy` to refresh the database. Idempotent: exits early if
   multilib is already enabled.
6. `scripts/nvidia.sh` — **NVIDIA hardware only** (see prerequisite 3).
   Clones `Frogging-Family/nvidia-all` shallow into
   `~/Downloads/nvidia-all`, runs `makepkg -si`, then removes the clone.
   Deliberately not idempotent in the original — do not run it twice on
   a machine that already has the driver working.

## Phase 3 — Curated package list (`packages.yml`)

`packages.yml` lives next to `scripts/` and uses one line per package:

```yaml
bat: pacman                 # plain comment describes the app
md.obsidian.Obsidian: flatpak # Obsidian notes
anytype-bin: yay
"@microsoft/inshellisense": npm   # quote names with special chars
# openfortigui: yay  # commented lines are ignored
```

- The `manager` is one of `pacman`, `yay`, `flatpak`, `npm`.
- `#` trailing comments describe the app; commented-out lines are skipped.
- The installer (`scripts/install_packages.sh`) parses it by reading
  non-comment lines as `package: manager`, stripping trailing comments
  from the manager field, and dispatching:

| manager | install command |
|---|---|
| `pacman` | `sudo pacman -S --needed --noconfirm <package>` |
| `yay` | `yay -S --needed --noconfirm <package>` |
| `flatpak` | `flatpak install -y --noninteractive <package>` |
| `npm` | `bun add --global <package> --no-confirm` (note: npm entries go through bun) |

- Install dependencies first: yay (Phase 2 covers it; re-check with
  `pacman -Qi yay`) and bun (`command -v bun`, else `yay -S bun-bin`).
- `--needed` means the list is safe to re-run; already-installed packages
  are skipped.
- Unknown managers print a warning and continue; do not abort the list.

Edit `packages.yml` (add/remove/comment lines) before this phase when
Matt wants a different set — the file is the source of truth.

## Phase 4 — Cleanup

```bash
sudo pacman -Scc --noconfirm
```

Clears the package cache so the fresh machine starts lean.

## Phase 5 — Reboot (user-controlled)

The program ends by asking whether to reboot now. **Do not reboot on your
own authority.** Present the choice; if yes, `reboot`. If no, remind that
a reboot is required before the machine is considered provisioned
(display manager, kernel modules, snapper all assume it).

## What this skill does NOT do

- **System updates on an existing machine** (`scripts/update.sh`) — that
  is a different skill with its own lifecycle. Never fold update logic in
  here.
- Anything in `scripts/` beyond the listed sequence (bluetooth, docker,
  kvm, virtualbox, symlink_configs) — those are standalone, opt-in tools,
  not part of fresh provisioning.

## Failure handling

- Fail-fast in Phase 2: first failing script stops the run.
- Phase 3 is failure-tolerant per package: log the failing package and
  manager, continue the list, and summarize all failures at the end.
- On any failure, report: phase, command, and the last ~20 lines of
  output. Never silently continue past a Phase 2 failure.
