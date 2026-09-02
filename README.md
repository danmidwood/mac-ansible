# macos_init

Ansible config for setting up and maintaining this Mac.

## Prerequisites (manual, before running Ansible)

On this machine (2017 13" MacBook Pro, macOS Ventura), the automatic
Command Line Tools channel (`softwareupdate`) only offers CLT 14.3.1 — it
doesn't offer the newer 15.x releases, even though Apple's docs list them
as Ventura 13.5+ compatible. To get a current toolchain, install the full
Xcode app manually instead of relying on `xcode-select --install`:

1. Download **Xcode 15.2** (the last version documented to support
   Ventura 13.5+) from the
   [Apple Developer downloads page](https://developer.apple.com/download/all/)
   (requires signing in with an Apple ID) and install it to `/Applications`.
2. Set it as the active developer directory so Homebrew and everything else
   uses it instead of the older standalone Command Line Tools, and accept
   its license:
   ```
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```

Once Xcode is installed and selected (`xcode-select -p` prints the path
into `Xcode.app`), the `xcode_clt` role in the playbook will see it's
already set up and skip its own install step.

Then continue with the "Fresh machine" instructions below.

## Fresh machine

```
./bootstrap.sh
```

Installs Xcode Command Line Tools, Homebrew, and Ansible (whatever's
missing), then runs the playbook.

## This machine / already bootstrapped

```
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml
```

`power_management` (`pmset -a`) and `sudoers` need root. With the
`sudoers` role already applied (passwordless sudo for `daniel`), no prompt
is needed. On a brand new machine, before that's set up, add
`--ask-become-pass` to be prompted once.

## Re-running

The playbook is idempotent and safe to run repeatedly — re-run it any time
to pick up new packages or update everything already installed
(`state: latest` on formulae/casks means a re-run upgrades them, roughly
equivalent to `brew upgrade`).

## Adding software

Edit `group_vars/all.yml`:

- `homebrew_formulae` — CLI tools
- `homebrew_casks` — GUI apps. Use `install_options: [adopt]` the first
  time for an app that's already in `/Applications` but wasn't installed
  via Homebrew, so Homebrew takes it over instead of refusing to install.
- `macos_defaults` — `defaults write`-style system preferences, applied via
  `community.general.osx_defaults`. Left empty on purpose; add entries as
  you decide you actually want them.

Claude Code (the CLI) is intentionally left out of `homebrew_casks` —
`roles/claude_code` installs it via its own native installer/self-updater
at `~/.local/bin/claude` instead, so it can auto-update in the background.
The Claude desktop app is a normal cask (`claude`) since it doesn't have
that self-update mechanism.

## Dotfiles

`roles/dotfiles` clones the private
[danmidwood/dotfiles](https://github.com/danmidwood/dotfiles) repo to
`~/repos/dotfiles` and applies it with chezmoi. Being a private repo, the
first clone on a new machine needs this machine's SSH key
(`roles/ssh_key`) added to GitHub first — see "Adding an SSH key to
GitHub on a new machine" below.

`~/.gitconfig` itself is entirely chezmoi's (`dot_gitconfig.tmpl` in the
dotfiles repo) — this repo no longer sets it directly. `roles/dotfiles`
seeds `git_user_email` and the fingerprint `roles/gpg_key` just generated
straight into chezmoi's `[data]` config before running `chezmoi init`, so
the dotfiles-managed gitconfig picks up this machine's identity and
signing key without an interactive prompt. (Not via `chezmoi init
--promptString` — that flag doesn't actually reach `promptStringOnce`,
see the comment in `roles/dotfiles/tasks/main.yml`.)

## GPG signing key

`roles/gpg_key` generates a **fresh, passphrase-less** GPG signing key on
each machine rather than copying one over from another — no private key
material ever has to move between machines, mirroring `roles/ssh_key`.
Passphrase-less is a deliberate trade (this machine already accepts others
for convenience: passwordless sudo, sleep disabled): a passphrase would
block every scripted/automated commit, not just interactive ones. Revoke
and regenerate the key by hand if that trade-off ever needs to change.

Like the SSH key, the first time this role runs it prints the new public
key and a link to add it: https://github.com/settings/gpg/new. Until it's
added there, GitHub just won't show your commits as "Verified" — nothing
else depends on it, so there's no need to stop and add it before
continuing (unlike the SSH key, which the very next role needs).

## Docker (CLI only, no Docker Desktop)

`roles/docker` installs the `docker` CLI, `colima` (runs the real,
upstream Docker Engine in a small Linux VM), and `docker-credential-helper`
(so `docker login` stores credentials in the macOS Keychain instead of
`~/.docker/config.json`'s default plaintext-ish base64). Docker Desktop's
company-size subscription terms only apply to the Docker Desktop app
itself -- Docker Engine is open source (Apache 2.0) and unaffected,
whichever way you obtain it.

The role sets `credsStore: osxkeychain` in `~/.docker/config.json`
(merging with, not overwriting, anything already there), but that's
inert until you actually run `docker login` -- nothing here signs you in
or requires an account. Starting the VM (`colima start`) is a deliberate
manual step, not run by this role: spinning up a VM isn't something to
do unattended on every deploy.

## Adding an SSH key to GitHub on a new machine

`roles/dotfiles` is the only role that needs GitHub to already trust this
machine's key. On a brand new machine, the straightforward path is: just
run the playbook. `roles/ssh_key` generates the key before `roles/dotfiles`
runs, so the first attempt fails there with the exact public key and a
link to paste it into (https://github.com/settings/keys) — add it, then
re-run. Every other role already succeeded on that first run and is
idempotent, so re-running only picks up where it left off.

## Time Machine (network/SMB destination)

`roles/time_machine` points Time Machine at a network share and enables
backups, but adding the destination needs two manual, one-time steps first
— `tmutil` can't do either non-interactively, so the role only detects and
confirms an already-configured destination (`tmutil destinationinfo`) and
skips re-adding it on every later run.

1. **Grant Full Disk Access** to whatever terminal app runs Ansible (e.g.
   Ghostty): System Settings → Privacy & Security → Full Disk Access → add
   the app → quit and reopen it. Without this, `tmutil setdestination`
   fails with `setdestination requires Full Disk Access privileges`.
2. **Add the destination once, interactively**, so the SMB password is
   typed straight into `tmutil` and never touches this repo or Ansible:
   ```
   sudo tmutil setdestination -a -p smb://<user>@<host>/<share>
   ```
   (`-p` prompts for the password securely.) A matching entry in the login
   or System Keychain is *not* enough on its own — `tmutil`, run as root by
   this role, doesn't reliably look it up there.

After both steps, `ansible-playbook playbook.yml` will see the destination
already listed and just ensure backups are enabled.

## Structure

```
playbook.yml            entry point
group_vars/all.yml       package lists / preferences (edit this most often)
roles/xcode_clt/         ensures Xcode Command Line Tools are installed
roles/homebrew/          taps, formulae, casks, cleanup
roles/claude_code/       installs Claude Code via its native installer
roles/docker/            docker CLI + colima (no Docker Desktop), osxkeychain creds
roles/ssh_key/           generates ~/.ssh/id_ed25519 if missing
roles/gpg_key/           generates a passphrase-less GPG signing key if missing
roles/dotfiles/          clones danmidwood/dotfiles, applies via chezmoi (owns ~/.gitconfig)
roles/sudoers/           passwordless sudo for daniel (needs sudo)
roles/power_management/  disables sleep/standby (failing SSD workaround, needs sudo)
roles/keyboard/          remaps Caps Lock to Control (LaunchAgent + hidutil)
roles/macos_defaults/    optional system preferences
roles/time_machine/      network (SMB) Time Machine destination, needs sudo
```
