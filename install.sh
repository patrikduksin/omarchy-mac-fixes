#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compatible="$(tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null || true)"

if [[ "$compatible" != *"apple,j314"* ]]; then
  printf 'This audio setup is only for Apple J314 MacBook Pro hardware.\n' >&2
  exit 1
fi

for required in \
  /usr/share/asahi-audio/j314/graph.json \
  /usr/share/asahi-audio/j314/mic.json
do
  if [[ ! -f "$required" ]]; then
    printf 'Missing required Asahi audio file: %s\n' "$required" >&2
    exit 1
  fi
done

render() {
  local source="$1" destination="$2" escaped_home
  escaped_home="${HOME//&/\\&}"
  install -d -m 755 "$(dirname -- "$destination")"
  sed "s|@HOME@|$escaped_home|g" "$source" >"$destination"
}

render "$repo_dir/audio/asahi-j314-mic.json.in" \
  "$HOME/.config/wireplumber/asahi-j314-mic.json"
render "$repo_dir/audio/asahi-j314-speakers.json.in" \
  "$HOME/.config/wireplumber/asahi-j314-speakers.json"
render "$repo_dir/audio/99-asahi.conf.in" \
  "$HOME/.config/wireplumber/wireplumber.conf.d/99-asahi.conf"
render "$repo_dir/audio/omarchy-audio-graph-guard.in" \
  "$HOME/.local/bin/omarchy-audio-graph-guard"
chmod 755 "$HOME/.local/bin/omarchy-audio-graph-guard"
render "$repo_dir/audio/omarchy-audio-graph-guard.service.in" \
  "$HOME/.config/systemd/user/omarchy-audio-graph-guard.service"

systemctl --user daemon-reload
systemctl --user enable omarchy-audio-graph-guard.service
if ! loginctl enable-linger "$USER"; then
  printf 'Warning: could not enable lingering; the guard will start at login instead of system boot.\n' >&2
fi
systemctl --user stop omarchy-audio-graph-guard.service 2>/dev/null || true
systemctl --user kill --kill-whom=all --signal=SIGKILL wireplumber.service 2>/dev/null || true
systemctl --user stop pipewire-pulse.socket pipewire-pulse.service pipewire.socket pipewire.service 2>/dev/null || true
systemctl --user reset-failed wireplumber.service
systemctl --user start pipewire.socket pipewire.service wireplumber.service pipewire-pulse.socket pipewire-pulse.service
systemctl --user start omarchy-audio-graph-guard.service

for _ in {1..20}; do
  if pactl list short sources 2>/dev/null | awk '$2 == "effect_output.j314-mic" { found=1 } END { exit !found }'; then
    printf 'J314 audio configuration installed successfully.\n'
    exit 0
  fi
  sleep 0.25
done

printf 'Audio services restarted, but the MacBook microphone did not appear.\n' >&2
exit 1
