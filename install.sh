#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-mac-fixes"
backup_dir="$state_dir/backups"
work_dir="$(mktemp -d)"
compatible="${OMARCHY_MAC_FIXES_COMPATIBLE:-/proc/device-tree/compatible}"
omarchy_dir="${OMARCHY_MAC_FIXES_OMARCHY_DIR:-${OMARCHY_PATH:-/usr/share/omarchy}}"
asahi_audio_dir="${OMARCHY_MAC_FIXES_ASAHI_AUDIO_DIR:-/usr/share/asahi-audio}"
machine_arch="${OMARCHY_MAC_FIXES_ARCH:-$(uname -m)}"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

is_apple_silicon() {
  [[ $machine_arch == "aarch64" ]] && [[ -r $compatible ]] && grep -Faiq 'apple,' "$compatible"
}

is_j314() {
  is_apple_silicon && grep -Faiq 'apple,j314' "$compatible"
}

backup_key() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

backup_once() {
  local target="$1" key status
  key="$(backup_key "$target")"
  status="$backup_dir/$key.status"
  [[ -e $status ]] && return

  mkdir -p "$backup_dir"
  printf '%s\n' "$target" >"$backup_dir/$key.path"
  if [[ -e $target || -L $target ]]; then
    cp -a -- "$target" "$backup_dir/$key.file"
    printf 'present\n' >"$status"
  else
    printf 'missing\n' >"$status"
  fi
}

install_managed() {
  local mode="$1" source="$2" target="$3"
  backup_once "$target"
  install -Dm"$mode" "$source" "$target"
}

apply_patch() {
  local patch_file="$1" target_dir="$2"
  patch --silent --batch --forward -p1 -d "$target_dir" <"$patch_file" ||
    fail "Patch no longer applies: ${patch_file#$repo_dir/}"
}

rewrite_managed_block() {
  local target="$1"
  local begin='# omarchy-mac-fixes: begin'
  local end='# omarchy-mac-fixes: end'
  local filtered="$work_dir/managed-block"

  mkdir -p "$(dirname "$target")"
  if [[ -f $target ]]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$target" >"$filtered"
  else
    : >"$filtered"
  fi

  while [[ -s $filtered ]] && [[ $(tail -c 1 "$filtered" | wc -l) -eq 0 ]]; do
    printf '\n' >>"$filtered"
  done
  {
    printf '%s\n' "$begin"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"'
    printf '%s\n' "$end"
  } >>"$filtered"
  install -m644 "$filtered" "$target"
}

install_screen_recording() {
  local source="$omarchy_dir/bin/omarchy-capture-screenrecording"
  local staged="$work_dir/omarchy/bin/omarchy-capture-screenrecording"

  [[ -r $source ]] || fail "Omarchy recorder not found: $source"
  mkdir -p "$(dirname "$staged")"
  cp -L -- "$source" "$staged"

  if ! grep -Fq -- '--no-dmabuf "${geom_args[@]}" -x yuv420p' "$staged"; then
    apply_patch "$repo_dir/patches/omarchy/screen-recording.patch" "$work_dir/omarchy"
  fi

  install_managed 755 "$staged" "$HOME/.local/bin/omarchy-capture-screenrecording"
  install_managed 755 "$repo_dir/files/bin/omarchy" "$HOME/.local/bin/omarchy"
  rewrite_managed_block "$HOME/.bashrc"
  rewrite_managed_block "$HOME/.config/uwsm/env"
}

install_j314_audio() {
  local source="$asahi_audio_dir/j314/mic.json"
  local staged="$work_dir/asahi-audio/j314/mic.json"
  local graph="$HOME/.local/share/omarchy-mac-fixes/audio/asahi-j314-mic-mono.json"
  local config="$HOME/.config/wireplumber/wireplumber.conf.d/99-asahi-j314-mic-mono.conf"
  local rendered="$work_dir/99-asahi-j314-mic-mono.conf"
  local escaped_graph

  [[ -r $source ]] || fail "J314 microphone graph not found: $source"
  mkdir -p "$(dirname "$staged")"
  cp -L -- "$source" "$staged"

  if ! grep -Fq '"audio.position": ["MONO"]' "$staged"; then
    apply_patch "$repo_dir/patches/asahi-audio/j314-mic-mono.patch" "$work_dir/asahi-audio"
  fi

  escaped_graph="$(printf '%s' "$graph" | sed 's/[&|\\]/\\&/g')"
  sed "s|@MIC_FILTER_PATH@|$escaped_graph|g" \
    "$repo_dir/files/wireplumber/99-asahi-j314-mic-mono.conf.in" >"$rendered"

  install_managed 644 "$staged" "$graph"
  install_managed 644 "$rendered" "$config"
  install_managed 755 \
    "$repo_dir/files/bin/omarchy-j314-mic-guard" \
    "$HOME/.local/bin/omarchy-j314-mic-guard"
  install_managed 644 \
    "$repo_dir/files/systemd/user/omarchy-j314-mic-guard.service" \
    "$HOME/.config/systemd/user/omarchy-j314-mic-guard.service"

  if [[ ${OMARCHY_MAC_FIXES_SKIP_SYSTEMD:-false} != "true" ]]; then
    systemctl --user daemon-reload
    systemctl --user restart wireplumber.service
    systemctl --user enable --now omarchy-j314-mic-guard.service
  fi

  mkdir -p "$state_dir"
  printf 'installed\n' >"$state_dir/j314-installed"
}

require_command patch
require_command sha256sum

is_apple_silicon || fail "This installer only supports Apple Silicon"

install_screen_recording
if is_j314; then
  install_j314_audio
else
  printf 'Skipping the J314 microphone fixes on this Mac model.\n'
fi

mkdir -p "$state_dir"
printf 'installed\n' >"$state_dir/status"

printf 'Installed Omarchy Mac fixes. Restart the desktop session to load the command override.\n'
