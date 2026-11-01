# Verification — THREADS 1.1

Verified 1 November 2026. See [update notes](UPDATE_1_1.md) for the reported issues and resulting changes.

## Current results

| Check | Result |
| --- | --- |
| Xcode | 27.1, build 27A9275 |
| SDK / simulator | visionOS 27.0 / Apple Vision Pro Simulator, arm64 |
| Simulator Debug build | Passed |
| Behavior and integration tests | 52 passed, 0 failed |
| Complete native UI test | 1 passed, 0 failed |
| Total | **53 passed, 0 failed, 0 skipped** |
| Physical-target optimized Release build | Passed with signing disabled; ARKit code compiled |
| Updated signed device build | Compilation completed; macOS signing authorization pending |
| Updated headset installation / wearer validation | Pending |

The complete suite passed before a final Tools layout adjustment. The native UI test was then rerun after moving Recenter and Play controls above the new settings; behavior code was unchanged by that adjustment. The UI flow verifies Sound moods, Echo trails, volume and Ambient, note and gesture controls, loop protections, Clear/Undo, Recenter, compact controls, Help, Reset, playing distance, tracking restart, guided-play entry, and three repeated exit/reentry cycles with exactly one control window. The sanitized machine-readable result is in `test-summary.json`; raw Xcode results remain local.

New behavior coverage includes partly occluded fingers, open-palm classification, relaxed waves outside the old narrow target box, closed/far/stationary/reacquired-hand rejection, jitter rejection, gentle fingertip strokes, single pending control-window requests, synthetic hand-to-wave integration, reach changes preserving a loop, head-space transform round trips, guided-note progression, retuning all three scales, finite echoes, and live contact not being swallowed or recursively recorded by echo tails. Existing geometry, synthesis/tuning, loop timing, gesture and scene-construction tests continue to pass.

## Visual inspection

The updated Sound and Tools panels were captured from the running simulator and checked for readable labels, native control layout, scrolling, one foreground dock, and available Close/Exit actions. These captures are in `Media/THREADS-update-sound.png` and `Media/THREADS-update-tools.png`. The older field/welcome/toolbar images remain historical captures from the original October build.

## Headset evidence

Version 1.0 was signed, installed and launched on a physical Vision Pro on 31 October; a running process was verified. The wearer subsequently reported unreliable waves and overlapping controls. Version 1.1 addresses these paths in code and regression tests. Its real hand tracking, wave reliability, comfortable reach, spatial localization, latency and sustained performance remain pending wearer confirmation. A simulator gesture button or a synthetic hand trajectory does not establish physical tracking success.

Use [the physical-device checklist](DEVICE_TEST_CHECKLIST.md) on the updated build. Signed output, provisioning profiles, device identifiers, signing settings and raw diagnostics are excluded from the repository.

## Earlier baseline

The original public-source suite passed 39 tests on 27 October 2026. The previous `--verify` run in `verification.json` measured simulator scene-update callbacks and audio mixer output for that earlier build. Those values are not new 1.1 performance measurements, compositor FPS or physical-device latency results. The offline 12-second `Media/THREADS-audio-study.wav` remains an illustration of the original synthesis and spatial audio graph, not a microphone or headset recording.

The app targets visionOS 26.0. The simulator cannot execute real ARKit hand/head tracking; the physical-target build compiles that path. Hand data and loops remain in memory, with no microphone capture, network service or analytics.
