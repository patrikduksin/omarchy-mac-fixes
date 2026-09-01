# omarchy-mac-fixes

Small Apple Silicon fixes that have not reached Omarchy or Asahi Audio yet.

## Install

```bash
./install.sh
```

Run it again whenever you want. It rebuilds each patched file from the
installed upstream copy, so repeated runs produce the same result.

The installer keeps package-owned files untouched. It installs user-owned
overrides, enables the J314 microphone guard, and adds `~/.local/bin` to the
front of the Bash and UWSM paths. Restart the desktop session after the first
install.

Remove the fixes with:

```bash
./uninstall.sh
```

Original files stay under `~/.local/state/omarchy-mac-fixes/backups`.

## Fixes

### Screen recording

[`patches/omarchy/screen-recording.patch`](patches/omarchy/screen-recording.patch)
makes the Asahi `wf-recorder` fallback avoid DMA-BUF imports and emit
`yuv420p`. The installer applies it to a user-owned copy of the Omarchy
command.

### J314 microphone channel

[`patches/asahi-audio/j314-mic-mono.patch`](patches/asahi-audio/j314-mic-mono.patch)
changes the processed microphone output from `AUX0` to `MONO`. The installer
patches a copy of the stock Asahi graph and selects it with a user WirePlumber
override.

### J314 microphone hot-plug recovery

[`files/bin/omarchy-j314-mic-guard`](files/bin/omarchy-j314-mic-guard) watches
PipeWire events and restarts WirePlumber only when the processed microphone
disappears. Its user service starts automatically.

## Test

```bash
./tests/test-install.sh
./tests/test-j314-mic-guard.sh
```
