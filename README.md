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

## Structure

```
playbook.yml            entry point
group_vars/all.yml       package lists / preferences (edit this most often)
roles/xcode_clt/         ensures Xcode Command Line Tools are installed
roles/homebrew/          taps, formulae, casks, cleanup
roles/claude_code/       installs Claude Code via its native installer
roles/git/               global git identity, init.defaultbranch
roles/ssh_key/           generates ~/.ssh/id_ed25519 if missing
roles/sudoers/           passwordless sudo for daniel (needs sudo)
roles/power_management/  disables sleep/standby (failing SSD workaround, needs sudo)
roles/keyboard/          remaps Caps Lock to Control (LaunchAgent + hidutil)
roles/macos_defaults/    optional system preferences
roles/time_machine/      network (SMB) Time Machine destination, needs sudo
```
