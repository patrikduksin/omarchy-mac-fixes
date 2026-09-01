#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -Dm755 \
  "$repo_dir/audio/omarchy-j314-mic-guard" \
  "$HOME/.local/bin/omarchy-j314-mic-guard"
install -Dm644 \
  "$repo_dir/audio/omarchy-j314-mic-guard.service" \
  "$HOME/.config/systemd/user/omarchy-j314-mic-guard.service"

systemctl --user daemon-reload
systemctl --user enable --now omarchy-j314-mic-guard.service
