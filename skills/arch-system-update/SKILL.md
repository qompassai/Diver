---
name: arch-system-update
description: >
  Matt's full Arch Linux system update ritual: snapper pre/post BTRFS
  snapshots, pacman repo refresh and system upgrade, AUR updates via paru,
  flatpak updates, conditional bun/dotnet/uv tool upgrades, orphan removal,
  snapshot pruning to the newest 100, and a reboot prompt when the kernel
  changed. Use when the user asks to "update my system", "run updates",
  "run the update ritual", "update everything", "update arch", or when
  "paru failed", "AUR update broke", or any update step reports an error.
license: Apache-2.0
compatibility: Arch Linux on a BTRFS root with snapper configured
  (snapper list-configs shows "root"), sudo available, and
  /usr/bin/snapper, /usr/bin/paru, /usr/bin/flatpak installed. bun, dotnet,
  and uv steps are skipped when not installed. Requires an interactive
  session for sudo and the end-of-run reboot decision.
metadata:
  managers: pacman, paru, flatpak, bun, dotnet, uv
  snapshot_tool: snapper
  prune_keep: "100"
  prune_scope: root config snapshots
  pre_snapshot_description: "backup: pre-system update"
  post_snapshot_description: "backup: post-system update"
  snapshot_config: root
  aur_cache: ~/.cache/paru/clone
  source: ~/.GH/dotfiles/arch/scripts/update.sh
allowed-tools: Read Edit Bash
---

# Arch System Update

Run Matt's full Arch Linux update ritual end to end. The steps below are
**ordered and gated** — do not reorder, skip, or run later steps after an
earlier step failed, except where the step's own fallback says otherwise.

## The ritual, in order

### 1. Pre-update snapshot (hard gate)

```bash
sudo snapper create -d "backup: pre-system update"
```

- If this fails, **stop immediately**. Do not run any update command.
  Everything else depends on a known-good restore point existing first.
- The pre-update description must be exactly `backup: pre-system update`
  (matches what his dotfiles script uses; snapshot hygiene downstream
  relies on consistent descriptions).

### 2. Refresh the pacman databases

```bash
sudo pacman -Syy
```

Abort the ritual if this fails — check the network connection first,
then re-run the whole ritual from step 1 (a fresh pre-snapshot is cheap).

### 3. Upgrade system packages

```bash
sudo pacman -Syu
```

Abort on failure. Read the output, do not force `-Syu --noconfirm`:
Matt wants to see conflicts and decide.

### 4. Update AUR packages

```bash
paru -Sua
```

See **Known failure: paru clone collision** below for the recurring
recovery path. No other paru failure has an in-ritual fallback: abort
and report.

### 5. Update Flatpaks

```bash
flatpak update -y
```

Abort on failure.

### 6. Language/toolchain managers (conditional, best-effort)

Each block runs **only if the binary exists** on PATH. These are
best-effort — a failure here logs a warning but does not abort the
ritual (a broken bun global should not block orphan cleanup or the
post-update snapshot).

- bun: `bun update -g`
- dotnet: `dotnet tool update --global --all`
- uv: there is no single "update all" command. Iterate installed
  tools and reinstall each:

```bash
uv tool list | awk 'NR>2 && NF>0 {print $1}' | while read -r tool; do
  if [ -n "$tool" ] && [ "$tool" != "-" ]; then
    echo "Updating $tool..."
    uv tool install "$tool" --reinstall
  fi
done
```

The `NR>2` skip discards `uv tool list`'s two header lines; the `"-"`
guard discards separator rows. Keep both guards — without them the loop
tries to install a tool named `-`.

### 7. Remove orphaned packages

```bash
ORPHANS=$(pacman -Qqdt)
if [ -n "$ORPHANS" ]; then
  sudo pacman -Rs $ORPHANS
else
  echo "No unused packages to remove."
fi
```

- `-Qqdt`: query quiet, dependencies, not required by any other package
  (`-t` = unrequired), i.e. true orphans.
- `-Rs`: remove with unneeded dependencies. Show the list before
  confirming — pacman prompts interactively by default, which is the
  desired behavior.

### 8. Post-update snapshot (hard gate)

```bash
sudo snapper create -d "backup: post-system update"
```

If this fails, the update already happened, so there is nothing to
"abort" — but **do not proceed to pruning or the reboot prompt until
the operator decides**. Report the failure and ask whether to retry the
snapshot or accept the pre-update snapshot as the restore point.
Description must be exactly `backup: post-system update`.

### 9. Prune snapshots to the newest 100

Delete the oldest snapshots, keeping the 100 most recent. One-by-one
deletion avoids command-line length limits:

```bash
OLD=$(sudo snapper list | awk 'NR>2 && $1!=0 {print $1}' | head -n -100)
for snap in $OLD; do
  [ -n "$snap" ] && sudo snapper delete "$snap"
done
```

- `NR>2` skips the `snapper list` header rows (the two-line header plus
  the `---` separator).
- `$1!=0` excludes snapshot 0 (the reserved "current" base).
- `head -n -100` keeps the last 100 lines = the 100 newest snapshots
  (`snapper list` orders by number, ascending, so the tail is newest).
- Log each deletion's success/failure; a single failed deletion does not
  stop the loop, but report failures at the end.

### 10. Reboot prompt

Ask, do not decide:

> The update is complete. If the kernel (`linux`, `linux-lts`, etc.)
> was upgraded in step 3, a reboot is strongly recommended.
> Reboot now? (y/n)

`sudo reboot` on `y`. On `n`, confirm the update completed without a
reboot. Check whether the kernel package changed by scanning the pacman
output from step 3 — do not reboot speculatively, and do not skip the
prompt just because the kernel looks unchanged.

## Known failure: paru clone collision

**Signature** (Matt hit this 2026-09-29): paru aborts an AUR build with

```
error: "<pkg>" already exists and is not an empty directory
```

pointing at `~/.cache/paru/clone/<pkg>`.

**Recovery**: the clone cache is stale/corrupt — it is safe to delete,
paru re-clones on the next run.

```bash
rm -rf ~/.cache/paru/clone/<pkg>
paru -Sua
```

Delete **only** the named package's directory, never the whole clone
cache — other in-progress builds may depend on their checkouts.
If the error names a different path (outside `~/.cache/paru/clone`),
do not `rm -rf` it: stop and ask.

## Known failure: snapshot creation fails

Hard stop at step 1 (pre-update): abort the entire ritual, fix snapper,
then start over. At step 8 (post-update): do not prune or prompt for
reboot until the operator resolves it (see step 8).

Common causes: `/.snapshots` not mounted, BTRFS quota out of space,
snapper config missing (`snapper list-configs` should show `root`).

## Rollback path

If the system is broken after the update:

```bash
sudo snapper list        # find the "backup: pre-system update" snapshot number
sudo snapper undochange <pre-snapshot>..<post-snapshot-or-0> /
```

- `snapper undochange A..B /` reverts the root subvolume to snapshot A.
- `snapper list-configs` must show the `root` config (set up by his
  `snapper.sh`: `snapper -c root create-config /`).
- For a full boot-level rollback (unbootable system), the dotfiles
  include `snapper-rollback` (AUR) configured against the root
  partition in `/etc/snapper-rollback.conf` — boot the pre-update
  snapshot from the bootloader and let it promote itself.
- Never delete the pre-update snapshot until the system is verified
  healthy after a reboot.

## Notes

- `sudo` is used for pacman/snapper; paru must run **as the user**
  (never `sudo paru`) — AUR builds run as an unprivileged user by
  design.
- The ritual is interactive: sudo prompts, pacman's removal
  confirmation, and the final reboot question all need the operator.
- Estimated cadence: Matt runs this as a standing maintenance ritual,
  not on a schedule — trigger is the user asking, or a stale-system
  finding from another check.
- Source of truth for this ritual: `~/.GH/dotfiles/arch/scripts/update.sh`
  in his dotfiles repo. If this skill and that script disagree, the
  script wins and this skill should be updated.

## Activation

<skill_resources>
manifest:
  files: []
  note: SKILL.md only. The ritual runs commands directly; no bundled
    scripts. The canonical script lives in Matt's dotfiles repo
    (~/.GH/dotfiles/arch/scripts/update.sh) and is referenced, not copied.
</skill_resources>

- **Per-session dedup**: never re-inject this skill into a session whose
  context already contains it. If the skill text is present, act on it —
  do not paste it again or summarize it back.
- **Subagent delegation verdict**: not needed. The update ritual requires
  Matt's live sudo authentication, his judgment on pacman conflicts and
  orphan removal, and his explicit reboot decision — all of which are
  interactive and session-local. A delegated subagent cannot hold that
  interactivity. Keep the whole ritual in-session, in the conversation
  where he asked for it.
