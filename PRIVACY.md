# Privacy and public source

THREADS needs no API keys, cloud service credentials, account login, networking, analytics or microphone access. ARKit hand and head transforms are processed locally for interaction and spatial audio. They are not recorded or uploaded.

Musical loops are note events held in memory for the current visit. The explicit `--verify` launch option writes local performance counters, audio levels and interaction counts. It does not store hand trajectories. The bundled audio study is generated instrument audio, not microphone audio.

## Files kept private

Personal signing configuration belongs in ignored `Configuration/LocalSigning.xcconfig`. Use the generic example or Xcode's local Signing settings for your own Team. Never commit your Team identifier, profiles, certificates, private keys or personal account details.

Raw Xcode result bundles, build products, simulator/device logs, user state, environment files and credential files are excluded. Public screenshots and the generated audio sample have metadata removed; color-encoding chunks are retained for consistent rendering.

## Before committing

```sh
python3 Scripts/audit_public.py --staged
python3 Scripts/audit_public.py --history
```

Enable the included optional local pre-commit guard with `git config core.hooksPath .githooks`. It reports file paths and rule names, without printing the matched sensitive text. A scanner is an additional check, not a guarantee against every possible disclosure. Review changes before publishing them.
