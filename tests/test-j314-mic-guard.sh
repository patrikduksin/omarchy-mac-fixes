#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_dir/files/bin/omarchy-j314-mic-guard"
unit="$repo_dir/files/systemd/user/omarchy-j314-mic-guard.service"
test_dir="$(mktemp -d)"
fake_bin="$test_dir/bin"
call_log="$test_dir/calls"

cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$fake_bin" "$test_dir/proc/asound/card1"
printf 'AppleJ314\n' >"$test_dir/proc/asound/card1/id"
: >"$call_log"

fail() {
  printf 'RED: %s\n' "$*" >&2
  exit 1
}

assert_count() {
  local expected="$1" pattern="$2" actual
  actual="$(grep -cFx "$pattern" "$call_log" || true)"
  [[ "$actual" == "$expected" ]] ||
    fail "expected $expected calls to '$pattern', got $actual"
}

[[ -x "$guard" ]] || fail "$guard is missing or not executable"
[[ -f "$unit" ]] || fail "$unit is missing"

cat >"$fake_bin/pactl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "list short sources")
    if [[ ${FAKE_MIC_PRESENT:-0} == 1 ]]; then
      printf '71\teffect_output.j314-mic\tPipeWire\tfloat32le 1ch 48000Hz\tSUSPENDED\n'
    else
      printf '61\talsa_input.platform-sound.HiFi__Headset__source\tPipeWire\ts32le 1ch 48000Hz\tSUSPENDED\n'
    fi
    ;;
  subscribe)
    printf "Event 'new' on card #1\n"
    printf "Event 'change' on source #61\n"
    printf "Event 'change' on server #0\n"
    sleep 0.12
    ;;
esac
EOF

cat >"$fake_bin/pw-metadata" <<'EOF'
#!/usr/bin/env bash
if [[ ${FAKE_STALE_DEFAULT:-0} == 1 ]]; then
  printf "update: id:0 key:'default.configured.audio.source' value:'{ \"name\": \"alsa_input.platform-sound.HiFi__Headset__source\" }' type:'Spa:String:JSON'\n"
fi
EOF

cat >"$fake_bin/amixer" <<'EOF'
#!/usr/bin/env bash
printf ': values=%s\n' "${FAKE_JACK_STATE:-off}"
EOF

for command in wpctl systemctl logger; do
  cat >"$fake_bin/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$FAKE_CALL_LOG"
EOF
done
chmod +x "$fake_bin"/*

run_guard() {
  PATH="$fake_bin:/usr/bin" \
    FAKE_CALL_LOG="$call_log" \
    OMARCHY_J314_MIC_PROC_ASOUND="$test_dir/proc/asound" \
    OMARCHY_J314_MIC_DEBOUNCE_SECONDS=0.05 \
    OMARCHY_J314_MIC_RECOVERY_TIMEOUT_SECONDS=0 \
    "$guard" "$@"
}

# A healthy graph must never be disturbed.
: >"$call_log"
FAKE_MIC_PRESENT=1 FAKE_STALE_DEFAULT=1 FAKE_JACK_STATE=off run_guard --recover
assert_count 0 'systemctl --user restart wireplumber.service'
assert_count 0 'wpctl clear-default 1'

# A missing DSP source is repaired. The stale headset default is cleared only
# when the physical headset jack is disconnected.
: >"$call_log"
FAKE_MIC_PRESENT=0 FAKE_STALE_DEFAULT=1 FAKE_JACK_STATE=off run_guard --recover
assert_count 1 'systemctl --user restart wireplumber.service'
assert_count 1 'wpctl clear-default 1'

: >"$call_log"
FAKE_MIC_PRESENT=0 FAKE_STALE_DEFAULT=1 FAKE_JACK_STATE=on run_guard --recover
assert_count 1 'systemctl --user restart wireplumber.service'
assert_count 0 'wpctl clear-default 1'

# Three events from one hot-plug burst must result in one recovery attempt.
: >"$call_log"
FAKE_MIC_PRESENT=0 FAKE_STALE_DEFAULT=0 FAKE_JACK_STATE=off run_guard --monitor
assert_count 1 'systemctl --user restart wireplumber.service'

grep -Fq 'After=wireplumber.service pipewire-pulse.service' "$unit" ||
  fail 'service is not ordered after the audio services'
grep -Fq 'Restart=always' "$unit" || fail 'service does not restart its event monitor'
grep -Fq 'WantedBy=default.target' "$unit" || fail 'service cannot be enabled at user startup'

printf 'GREEN: J314 microphone guard behavior is correct\n'
