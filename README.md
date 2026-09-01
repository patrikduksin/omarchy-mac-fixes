# omarchy-mac-fixes

Minimal user configuration fixes for Omarchy Mac.

## J314 built-in microphone

Asahi Audio exposes the processed J314 microphone as one `AUX0` channel.
Quickshell's peak monitor and some WebRTC clients expect a standard mono
channel, so the Omarchy input meter stays flat and applications may receive no
input.

The files under `audio/` keep Asahi's three raw beamforming channels and expose
only the processed output as `MONO`:

- `audio/asahi-j314-mic-mono.json` is the patched Asahi microphone graph.
- `audio/99-asahi-j314-mic-mono.conf` selects that graph for Apple J314 and
  keeps the packaged J314 speaker graph.

An installer must replace `@MIC_FILTER_PATH@` in the WirePlumber config with
the absolute installed path of `asahi-j314-mic-mono.json`.

## J314 microphone hot-plug recovery

`audio/omarchy-j314-mic-guard` listens for PipeWire card, source, and server
events. It waits 500 ms after the last event, then checks for the processed
`effect_output.j314-mic` source. If that source is missing, it restarts only
WirePlumber.

Before recovery, the guard clears the configured headset microphone only when
the Apple ALSA jack control reports that the headset is unplugged. Other input
selections remain untouched.

Install and enable the user service at startup:

```bash
./install-audio-guard.sh
```

Run the mocked regression test with:

```bash
./tests/test-j314-mic-guard.sh
```
