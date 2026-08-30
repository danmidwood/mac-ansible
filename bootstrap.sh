#!/usr/bin/env bash
# One-time bootstrap for a fresh macOS machine: gets just enough in place
# (Command Line Tools, Homebrew, Ansible) to hand off to the playbook, then
# runs it. Safe to re-run.
set -euo pipefail

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Finish the Command Line Tools install, then re-run this script."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Installing Ansible..."
  brew install ansible
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml --ask-become-pass
