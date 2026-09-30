---
name: rosenpass-pqc-vpn
description: >
  Post-quantum-secure WireGuard tunnel setup with Rosenpass. Adds a
  post-quantum key exchange in front of WireGuard so a future quantum
  computer cannot retroactively break recorded handshakes
  (harvest-now-decrypt-later). Covers: installing rosenpass and
  wireguard-tools, generating a Rosenpass public/secret keypair with
  `rosenpass gen-keys`, writing the TOML config with [[peers]] entries
  (peer public_key, endpoint host:9999, key_out, exchange_command feeding
  the exchanged PSK into `wg set wg0 ... preshared-key /dev/stdin`), and
  running the daemon with `rosenpass exchange-config`. Use when the user
  asks for a "post-quantum VPN", "rosenpass wireguard", "quantum-safe
  tunnel", "harden wireguard against quantum", or mentions rpconf.sh,
  qompass.yml, or Rosenpass PSK exchange.
license: Apache-2.0
compatibility: >
  Arch Linux with the `rosenpass` (0.2.2-2 verified on primo,
  /usr/bin/rosenpass) and `wireguard-tools` (1.0.20260223-1 verified on
  primo, /usr/bin/wg) packages installed. Install step:
  `paru -S rosenpass wireguard-tools`. Requires an existing WireGuard
  interface (e.g. wg0) with peers already configured, root/sudo for
  `wg set`, and network reachability to the peer on UDP 9999.
metadata:
  pqc_kex: rosenpass
  vpn: wireguard
  psk_exchange: wg set wg0 peer <PEER_ID> preshared-key /dev/stdin
  config_template: /home/phaedrus/.GH/Rosenpass/rpconf.sh
  config_name: qompass.yml
  rosenpass_bin: /usr/bin/rosenpass
  wg_bin: /usr/bin/wg
  keygen: rosenpass gen-keys -p <pubfile> -s <secretfile>
  daemon: rosenpass exchange-config <config>
  default_listen_port: "9999"
allowed-tools: Read Edit Bash
---

# Rosenpass + WireGuard (post-quantum VPN)

WireGuard's handshake uses classical public-key crypto. Rosenpass runs a
separate post-quantum key exchange on UDP 9999 and feeds the resulting
shared secret into WireGuard as a pre-shared key via
`wg set ... preshared-key /dev/stdin`. The WireGuard session then needs
*both* the classical handshake and the quantum-resistant PSK to be
compromised — recorded traffic stays safe against future quantum
decryption (harvest-now-decrypt-later). This skill is the operations
playbook; it is not a cryptography explainer.

Verified against rosenpass 0.2.2-2 on primo (2026-09-29). All command
syntax below is from `rosenpass --help` output, not from memory.

## 0. Verify the binaries first

Never assume the tools are installed. The package name is **not** the
binary name here (`rosenpass` ships both `rosenpass` and `rp`), so run
the three-step check:

```bash
paru -Q rosenpass && paru -Q wireguard-tools            # (1) packages installed?
pacman -Ql rosenpass | grep -E '/s?bin/'                # (2) actual binaries
pacman -Ql wireguard-tools | grep -E '/s?bin/'
command -v rosenpass && command -v wg                   # (3) on PATH?
bash -lc 'command -v rosenpass; command -v wg'         # login-shell PATH too
```

Expected (primo, 2026-09-29):

```
rosenpass 0.2.2-2
wireguard-tools 1.0.20260223-1
rosenpass /usr/bin/rosenpass
rosenpass /usr/bin/rp
wireguard-tools /usr/bin/wg
wireguard-tools /usr/bin/wg-quick
/usr/bin/rosenpass
/usr/bin/wg
```

If either package is missing, install it (Arch):

```bash
paru -S rosenpass wireguard-tools
```

`rosenpass` is the CLI; `/usr/bin/rp` is the same binary under a short
alias. There is no `rosenpass genkey` subcommand — the real keygen is
`rosenpass gen-keys` (see step 1).

## 1. Generate the keypair

`rosenpass gen-keys` writes a fresh secret key and derives its public key:

```bash
rosenpass gen-keys -p rp-public-key -s rp-secret-key
```

- `-p/--public-key <file>`: where to write the public key.
- `-s/--secret-key <file>`: where to write the secret key.
- `-f/--force`: overwrite existing key files (never use this on a live
  key in production — it orphans every peer holding the old public key).
- With no `[CONFIG_FILE]` argument, the paths come from the flags. Given
  a config file, the destinations are read from its `public_key` /
  `secret_key` fields.

**The secret key is a credential.** NEVER commit `rp-secret-key` (or any
secret key) to git, never paste it into chat, never copy it to shared
storage. Permissions should be owner-only: `chmod 600 rp-secret-key`.

Repeat this on **each endpoint** — both sides of the tunnel need their
own keypair. Exchange public keys out of band (QR, ssh, encrypted
message — the public key is public, the channel just needs integrity).

## 2. Write the config file

Matt's dotfiles template generator is
`/home/phaedrus/.GH/Rosenpass/rpconf.sh`. It writes `qompass.yml` — the
canonical Rosenpass demo config with the endpoint set to this machine's
hostname on port 9999:

```bash
bash /home/phaedrus/.GH/Rosenpass/rpconf.sh   # writes qompass.yml
```

The generated file (placeholders marked — **must be replaced**):

```toml
public_key = "rp-public-key"
secret_key = "rp-secret-key"
listen = []
verbosity = "Quiet"

[[peers]]
public_key = "rp-peer-public-key"   # <- the PEER's public key file path
endpoint = "<this-hostname>:9999"   # <- the PEER's reachable host:port
key_out = "rp-key-out"
exchange_command = [
    "wg",
    "set",
    "wg0",
    "peer",
    "<PEER_ID>",                    # <- the peer's WireGuard public key
    "preshared-key",
    "/dev/stdin",
]
```

What each field means:

- `public_key` / `secret_key`: paths to **your own** keypair files from
  step 1. The values `rp-public-key` / `rp-secret-key` are placeholder
  names — use the real paths you generated.
- `listen`: empty list = listen on all interfaces (default port 9999).
  Fill it only to bind specific addresses.
- `[[peers]] public_key`: path to a file containing the **peer's**
  Rosenpass public key (exchanged in step 1).
- `[[peers]] endpoint`: where to initiate the exchange, `host:9999`.
  The template fills in *your* hostname as a starting point — replace it
  with the peer's actual reachable hostname/IP. Omit the endpoint only
  for a responder-only peer (it will answer initiations but never dial).
- `[[peers]] key_out`: file receiving the exchanged PSK. Mostly a
  debugging artifact here — the real handoff is `exchange_command`.
- `[[peers]] exchange_command`: runs on every completed key exchange.
  This one pipes the fresh PSK into WireGuard: `wg set wg0 peer
  <PEER_ID> preshared-key /dev/stdin`, where `<PEER_ID>` is the peer's
  **WireGuard** public key (base64, the one in your `[Peer]`
  `PublicKey = ...` line — not the Rosenpass key).

You can get a fresh canonical demo config any time with:

```bash
rosenpass gen-config -f /tmp/rp-demo.toml
```

(`-f` overwrites.) This is byte-identical to the template apart from the
endpoint — the rpconf.sh script exists to inject the dynamic hostname.

Validate a config before running it:

```bash
rosenpass validate qompass.yml
```

`[[peers]]` is a TOML array — repeat the whole block for each peer, each
with its own public key, endpoint, and WireGuard peer ID.

## 3. Run the daemon and verify

Rosenpass needs an existing WireGuard interface with the peer already
configured (WireGuard does the transport; Rosenpass only supplies the
PSK). Bring up `wg0` first (`wg-quick up wg0` or your normal method).

Then start the exchange:

```bash
sudo rosenpass exchange-config qompass.yml
```

- An instance with a peer `endpoint` set actively dials the peer on UDP
  9999; a peer without `endpoint` only responds to initiations. Both
  directions work once reachable.
- Each successful exchange fires `exchange_command`, which installs the
  new PSK on the WireGuard peer. Rosenpass re-exchanges periodically, so
  the PSK rotates without you touching it.

Verify:

```bash
sudo wg show wg0          # peer should show a recent "latest handshake"
```

- `latest handshake` updating after starting rosenpass confirms traffic
  is flowing through the PSK-protected session.
- If no handshake appears: check UDP 9999 reachability (`ss -uln |
  grep 9999` on the responder, firewall rules on both sides), confirm the
  peer's Rosenpass public key in your config matches what the peer
  generated, and confirm `<PEER_ID>` matches the peer's WireGuard
  `PublicKey` exactly (Rosenpass keys and WireGuard keys are different
  keypairs — mixing them up is the most common failure).
- Run with `verbosity = "Verbose"` in the config while debugging; return
  it to `"Quiet"` after.

## Safety rules (non-negotiable)

- **Never commit or share the secret key.** Add `rp-secret-key` (and any
  `*-secret-key`) to `.gitignore` before the key files exist in the
  directory. If a secret key ever touches a public repo, rotate it
  (regenerate with `gen-keys`, redistribute the new public key) — there
  is no "unshare".
- `<PEER_ID>` is the peer's WireGuard public key, the peer's
  `[[peers]] public_key` is their Rosenpass public key. They are
  different formats, different keypairs. Do not swap them.
- Placeholders in the template (`rp-public-key`, `rp-secret-key`,
  `rp-peer-public-key`, `<PEER_ID>`, `my-peer.test` / your own hostname)
  are not valid values. A config that still contains them will not
  establish a real exchange — `rosenpass validate` catches syntax, not
  placeholder content. Read the file before starting the daemon.

## Activation

<skill_resources>
manifest:
  files: []
  note: SKILL.md only. Key generation and config templating run through
    the installed `rosenpass` binary (`gen-keys`, `gen-config`) and
    Matt's template script
    (/home/phaedrus/.GH/Rosenpass/rpconf.sh); nothing is bundled in
    the skill.
</skill_resources>

- **Per-session dedup**: never re-inject this skill into a session whose
  context already contains it. If the skill text is present, act on it —
  do not paste it again or summarize it back.
- **Subagent delegation verdict**: optional/partial. The one-time
  interactive setup is best done in-session: sudo for `wg set` /
  `exchange-config`, live verification of the WireGuard handshake, and
  back-and-forth with Matt on peer hostnames, public-key exchange, and
  firewall rules are all session-local and interactive. A subagent may
  handle the mechanical pre-work (binary verification, `gen-keys`,
  template generation, `validate`) and hand back a ready config for Matt
  to review before the daemon starts — but the daemon run and the
  handshake verification stay in the conversation where he can see and
  approve them.
