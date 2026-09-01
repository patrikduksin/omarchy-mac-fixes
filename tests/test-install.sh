#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
fake_home="$test_dir/home"
fake_state="$test_dir/state"
fake_omarchy="$test_dir/omarchy"
fake_asahi="$test_dir/asahi-audio"
compatible="$test_dir/compatible"

cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
  printf 'RED: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$fake_home/.local/bin" "$fake_omarchy/bin" "$fake_asahi/j314"
printf 'apple,j314s\n' >"$compatible"
printf '# original local omarchy\n' >"$fake_home/.local/bin/omarchy"
printf '# original bashrc\n' >"$fake_home/.bashrc"
cp "$fake_home/.local/bin/omarchy" "$test_dir/original-omarchy"
cp "$fake_home/.bashrc" "$test_dir/original-bashrc"

cat >"$fake_omarchy/bin/omarchy-capture-screenrecording" <<'EOF'
#!/usr/bin/env bash

launch_wf_recorder() {
  # -r 60 caps the framerate: capturing a 120 Hz panel at its native rate makes
  # needlessly large files. wf-recorder's default libx264 is CPU-encoded, which
  # is the only option on Asahi (no supported hardware encoder).
  wf-recorder "${geom_args[@]}" -r 60 "${audio_args[@]}" -f "$filename" 2>>"$LOG_FILE" &
  REC_PID=$!
}
EOF
chmod +x "$fake_omarchy/bin/omarchy-capture-screenrecording"

cat >"$fake_asahi/j314/mic.json" <<'EOF'
{
    "playback.props": {
        "node.name": "effect_output.j314-mic",
        "media.class": "Audio/Source",
        "priority.session": 2005,
        "node.passive": "true",
        "audio.channels": "1",
        "node.virtual": "false",
        "state.default-volume": 0.343,
        "audio.allowed-rates": [8000, 11025, 16000, 22050, 44100, 48000],
        "audio.position": ["AUX0"]
    }
}
EOF

run_installer() {
  HOME="$fake_home" \
    XDG_STATE_HOME="$fake_state" \
    OMARCHY_MAC_FIXES_ARCH=aarch64 \
    OMARCHY_MAC_FIXES_COMPATIBLE="$compatible" \
    OMARCHY_MAC_FIXES_OMARCHY_DIR="$fake_omarchy" \
    OMARCHY_MAC_FIXES_ASAHI_AUDIO_DIR="$fake_asahi" \
    OMARCHY_MAC_FIXES_SKIP_SYSTEMD=true \
    "$repo_dir/install.sh"
}

run_uninstaller() {
  HOME="$fake_home" \
    XDG_STATE_HOME="$fake_state" \
    OMARCHY_MAC_FIXES_SKIP_SYSTEMD=true \
    "$repo_dir/uninstall.sh"
}

installed_hash() {
  find "$fake_home" "$fake_state" -type f -print0 |
    sort -z |
    xargs -0 sha256sum
}

run_installer >/dev/null
first_hash="$(installed_hash)"
run_installer >/dev/null
second_hash="$(installed_hash)"

[[ $first_hash == "$second_hash" ]] || fail 'a second install changed managed files'
grep -Fq -- '--no-dmabuf "${geom_args[@]}" -x yuv420p' \
  "$fake_home/.local/bin/omarchy-capture-screenrecording" ||
  fail 'screen recorder patch was not installed'
grep -Fq '"audio.position": ["MONO"]' \
  "$fake_home/.local/share/omarchy-mac-fixes/audio/asahi-j314-mic-mono.json" ||
  fail 'microphone graph patch was not installed'
[[ $(grep -cFx '# omarchy-mac-fixes: begin' "$fake_home/.bashrc") == 1 ]] ||
  fail 'PATH block was duplicated'

run_uninstaller >/dev/null
cmp -s "$test_dir/original-omarchy" "$fake_home/.local/bin/omarchy" ||
  fail 'uninstall did not restore the original command'
cmp -s "$test_dir/original-bashrc" "$fake_home/.bashrc" ||
  fail 'uninstall did not restore the original Bash configuration'
[[ ! -e $fake_home/.local/bin/omarchy-capture-screenrecording ]] ||
  fail 'uninstall left the recorder override behind'
[[ ! -e $fake_home/.local/share/omarchy-mac-fixes/audio/asahi-j314-mic-mono.json ]] ||
  fail 'uninstall left the microphone graph behind'

printf 'GREEN: installer is idempotent and uninstall restores prior files\n'
