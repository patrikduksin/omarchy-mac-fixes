#!/usr/bin/env bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-mac-fixes"
backup_dir="$state_dir/backups"
work_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

backup_key() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

restore_managed() {
  local target="$1" key status
  key="$(backup_key "$target")"
  status="$backup_dir/$key.status"
  [[ -r $status ]] || fail "No install record for $target"

  case "$(<"$status")" in
  present)
    mkdir -p "$(dirname "$target")"
    cp -a --remove-destination "$backup_dir/$key.file" "$target"
    ;;
  missing)
    rm -f -- "$target"
    ;;
  *)
    fail "Invalid backup record for $target"
    ;;
  esac
}

remove_managed_block() {
  local target="$1"
  local begin='# omarchy-mac-fixes: begin'
  local end='# omarchy-mac-fixes: end'
  local filtered="$work_dir/managed-block"

  [[ -f $target ]] || return
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$target" >"$filtered"
  install -m644 "$filtered" "$target"
}

[[ -r $state_dir/status ]] && [[ $(<"$state_dir/status") == "installed" ]] ||
  fail "Omarchy Mac fixes are not installed"

if [[ ${OMARCHY_MAC_FIXES_SKIP_SYSTEMD:-false} != "true" ]]; then
  systemctl --user disable --now omarchy-j314-mic-guard.service >/dev/null 2>&1 || true
fi

restore_managed "$HOME/.local/bin/omarchy-capture-screenrecording"
restore_managed "$HOME/.local/bin/omarchy"

if [[ -r $state_dir/j314-installed ]]; then
  restore_managed "$HOME/.local/share/omarchy-mac-fixes/audio/asahi-j314-mic-mono.json"
  restore_managed "$HOME/.config/wireplumber/wireplumber.conf.d/99-asahi-j314-mic-mono.conf"
  restore_managed "$HOME/.local/bin/omarchy-j314-mic-guard"
  restore_managed "$HOME/.config/systemd/user/omarchy-j314-mic-guard.service"
fi

remove_managed_block "$HOME/.bashrc"
remove_managed_block "$HOME/.config/uwsm/env"

if [[ ${OMARCHY_MAC_FIXES_SKIP_SYSTEMD:-false} != "true" ]]; then
  systemctl --user daemon-reload
  systemctl --user restart wireplumber.service
fi

printf 'uninstalled\n' >"$state_dir/status"
printf 'Removed Omarchy Mac fixes. Original files remain in %s.\n' "$backup_dir"
