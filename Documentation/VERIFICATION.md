# Verification — THREADS

Original instrument verification: 25 October 2026. The sanitized public-source checkout was rebuilt and all 39 tests passed again on 27 October 2026. Publication checks are recorded in SecurityAudit.md.

## Build and test results

| Check | Result |
| --- | --- |
| Xcode | 27.1, build 27A9275 |
| SDK | visionOS / visionOS Simulator 27.0 |
| Simulator target | Apple Vision Pro, visionOS 27.0 (24M362), arm64 |
| Simulator Debug build | Passed |
| Physical-target optimized Release build | Passed, unsigned; compilation only |
| Automated behavior / integration tests | 38 passed, 0 failures |
| Native simulator UI test | 1 passed, 0 failures |
| Total | **39 passed, 0 failed, 0 skipped** |
| Physical deployment | Not performed |

The native UI test exercises entry, Sound and precise volume changes, Ambient, Play controls, Wave / Resonate / Stretch, recording, cancellation of replacement, pause, Clear / Undo, Recenter with a preserved loop, cancellation of Exit, compact / expanded controls, Help, Reset and return to the welcome window. See TOOLBAR_UX.md for the redesign decisions and remaining device checks. See `test-summary.json` for the sanitized machine-readable summary. Raw Xcode result bundles remain local and are intentionally excluded from the public source.

Behavior tests cover finite segment intersections and degeneracy, physical reach, valid mesh indices, actual fingertip crossings, movement rejection, contact rearming, cooldown behavior, loss-of-tracking reset, damped motion, fixed endpoints, reduced motion, bounded stretching, clearing state, loop timing and boundaries, pauses, stalls, automatic recording stop, storage bounds, waveform headroom / attack / decay / repeatability, measured tuning of all ten rendered acoustic notes within ten cents, and construction of the actual RealityKit scene.

## Timed simulator performance

A separate `--verify` run exercised a performance, stretching, wave, resonance, record / playback / pause / resume, reset and exit. Its local report is `verification.json`.

- 520 decorative filaments; 10 interactive strings; 76,160 triangles in batched decorative lattices and ribbons. Architecture, rings and interactive geometry are additional.
- 2,503 RealityKit scene-update callbacks over the run. Mean callback interval: **8.51 ms**; 95th percentile: **11.11 ms**. These measure simulator scene-update cadence, not compositor frame rate or physical-device GPU performance.
- Audio mixer tap observed **1,017,600 frames** with nonzero peak **0.0492**. This establishes signal through the running mixer, not perceived sound quality or end-to-end gesture latency.
- Ten demo notes, one stretch release, three wave notes, four resonance notes, and **11 loop playback events** were observed.
- The report records `entered` through `exited`. At the end, recording is cleared, loop state is empty, and `audioReady` is false because Exit has paused the engine as intended.

## Visual inspection

`Media/THREADS-field.png`, `Media/THREADS-toolbar-sound.png`, `Media/THREADS-toolbar-loop.png` and `Media/THREADS-welcome.png` are actual simulator captures of the final build. The field image visibly confirms the architectural lattices, ceiling ribbons, circular platforms, foreground instrument, contact beads, light pulse and secondary controls. They are not generated concept images.

The final 39-test run, refreshed runtime measurements and current captures were collected on an Apple Vision Pro simulator. Earlier shared-simulator capture attempts could be black after repeated test sessions. Screenshot attachments inside the XCTest bundle can be blank on this platform; the separate simulator captures are the visual evidence.

## Audio study

`Media/THREADS-audio-study.wav` is a 12-second, 48 kHz stereo study rendered offline with the same acoustic synthesis, positional Apple audio environment, and warm hall reverb. It is an illustrative native audio render, not a headset recording or microphone capture. Its peak is 0.2429, RMS 0.0267, and it contains zero clipped samples.

## Remaining physical verification

Real ARKit fingertip and pinch reliability, comfortable reach, raw-hand gesture recognition, tracking loss / reacquisition, real audio localization, headset speaker balance, motion-to-sound latency, sustained frame performance / thermals and user comfort remain unverified. The physical Release build verifies API compatibility and compilation only. Use `DEVICE_TEST_CHECKLIST.md` while wearing the headset.

The simulator uses explicit note / gesture controls and a fixed seated instrument/listener position; it cannot validate real hand tracking or head-relative ARKit calibration. The physical build uses tracked head position and orientation and HRTF spatialization; the simulator uses spherical-head spatialization as a reliable fallback. The redesigned native controls require visionOS 26.0 or later. Only visionOS 27.0 was run-tested in the simulator; physical-device and older supported OS compatibility still need device verification.

Loops are in memory and clear on exit; there is no persistence, microphone capture, continuous granular stretch synthesis, advanced shader, or true volumetric scattering. Stretch tension is heard as rate-shifted acoustic excitations and a release note. Reflections use restrained material lighting and stylized floor light pools. Physical hardware tuning may change thresholds, brightness, mix, or strand density after user testing.

## Apple references used

- [Tracking and visualizing hand movement](https://developer.apple.com/documentation/visionos/tracking-and-visualizing-hand-movement) informed joint-transform handling; the installed ARKit SDK was also inspected.
- [AVAudioEnvironmentNode](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode) provides world-positioned mono sources and listener orientation.
- [Configuring your app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon) describes visionOS layered icons; the project includes an original three-layer procedural icon based on Xcode's installed asset template.
