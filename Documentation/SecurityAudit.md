# Public-source audit

Initial publication audit: 27 October 2026.

Update audit: 1 November 2026. THREADS 1.1 adds the wave/window corrections and four musical/comfort features described in UPDATE_1_1.md. The updated suite passed 53 tests and the physical-target optimized build passed with signing disabled. Updated simulator captures contain only the app and have ancillary text/EXIF metadata removed. Local signing, raw results and device diagnostics remain excluded. Exact staged files, exported source and reachable history are rechecked before publication; source checksums are regenerated for this update.

The original publication procedure below is retained as a historical record.

The public source was prepared in a separate clean checkout of the supplied empty repository. No earlier local project history was copied. Application Swift sources and project settings are unchanged; documentation and generated media were sanitized for publication.

## Checks

- Excluded 120 raw Xcode result files, including their internal result database and diagnostic blobs. No build products, profiles, private signing file, local user state, logs, environment files or compiled Python cache are included.
- Removed 10 ancillary PNG/audio metadata chunks. The image pixel data and generated audio samples are unchanged. Retained screenshots show only the application and the simulator's generic environment.
- Scanned the exact staged files for credentials, private keys, device identifiers, personal paths/emails, private network addresses, unsafe file classes and metadata. The guard reports rule names and relative paths without exposing matching values.
- Gitleaks 8.30.1 file scan: no credential findings. Staged/history and exported-source checks are required before the first push.
- Private personal-name/path checks: zero findings. These private match lists are intentionally not included in the public repository.
- Public-source simulator verification: **39 passed, 0 failed, 0 skipped**, using Xcode 27.1 and visionOS Simulator 27.0. No physical-device testing is claimed.
- The first commit uses a project contributor label and a reserved non-personal email address. No personal name, account email or signing identity is copied into Git history.

The repository requires no API keys. Only generic signing placeholders are supplied. `PRIVACY.md`, the expanded ignore rules and the optional pre-commit guard help keep future local files private. `SourceSHA256.json` records checksums for the published source files; GitHub's repository URL identifies the account chosen by the owner.

Raw audit reports and raw Xcode test results remain local. Automated scans cover known patterns and file classes; they do not guarantee detection of every possible secret. Future changes must be reviewed and scanned again.
