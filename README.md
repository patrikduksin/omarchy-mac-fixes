# omarchy-mac-fixes

Personal configuration for Omarchy on an Apple J314 MacBook Pro with M1 Pro or
M1 Max.

## Audio setup

This repository tracks the local audio changes needed on this machine:

- exposes the processed Asahi microphone as standard mono audio;
- names the devices `MacBook Built-in Microphone` and
  `MacBook Built-in Speakers`;
- keeps the Asahi speaker and microphone DSP graphs intact;
- detects broken PipeWire graphs after USB-C or 3.5 mm audio changes and
  rebuilds them automatically;
- selects newly connected audio devices, moves active application streams,
  and returns to the MacBook devices after external devices disconnect.

The audio guard checks the graph every two seconds. It restarts WirePlumber
when a required MacBook device is missing or duplicate source or sink names
exist. It rebuilds PipeWire only if restarting WirePlumber does not repair the
graph. Recovery causes a short audio interruption.

When several external devices are connected, the newest one becomes the
default. Disconnecting it selects another external device if one remains.
Otherwise, the guard selects the MacBook microphone or speakers. The guard
moves active application streams when the selected device changes.

For the 3.5 mm jack, the guard reads the Apple ALSA jack controls instead of
trusting PipeWire's node list. This prevents stale headset nodes from being
selected after unplugging the cable.

## Install on a clean machine

Requirements:

- Omarchy Mac on Apple J314 hardware;
- `asahi-audio`, PipeWire, and WirePlumber installed;
- a logged-in graphical user session.

Run:

```bash
git clone <repository-url> ~/Work/omarchy-mac-fixes
cd ~/Work/omarchy-mac-fixes
./install.sh
```

The installer refuses to run on hardware other than Apple J314. It renders
the current home directory into paths that WirePlumber and systemd require,
enables user lingering so the guard starts during system boot, enables the
recovery guard, and rebuilds the audio graph. If logind refuses to enable
lingering, the guard still starts when the user logs in.

## Verify

```bash
systemctl --user status omarchy-audio-graph-guard
pactl list short sources
pactl list short sinks
```

The source list should contain one `effect_output.j314-mic`. The sink
description should be `MacBook Built-in Speakers`.
