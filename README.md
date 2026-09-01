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
