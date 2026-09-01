# omarchy-mac-fixes

The experimental J314 audio patch was removed on September 1, 2026. The live
machine was returned to packaged Omarchy Mac, Asahi Audio, PipeWire, and
WirePlumber configuration.

The experiment attempted to repair audio graphs and manage defaults across
USB-C and 3.5 mm hot-plug events. Automatic recovery caused repeatable crashes
in Quickshell 0.3.1 and eventually WirePlumber itself, so none of the patch is
kept on `main`.

The earlier implementation remains available in Git history for diagnosis.
Do not restore it as-is. A future attempt should start from the packaged audio
configuration and reproduce the hot-plug failure before changing any files.
