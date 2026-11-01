# THREADS — Resonance Field

**An instrument made of light.** A native visionOS prototype for Apple Vision Pro: an original, fully three-dimensional chamber of luminous filaments, with an intimate ten-string acoustic instrument at its center.

Open `THREADS.xcodeproj`, choose the shared **THREADS** scheme, select an Apple Vision Pro simulator, and Run. The welcome window opens first; choose **Enter the Field**. The movable native dock contains Record, Play/Pause, Sound, Tools and Exit. Choose **Tools → Play controls** for the ten note keys plus Stretch, Wave and Resonate. **Exit** remains available in compact mode. If you close the control window, **Show controls** in the field restores it.

![THREADS running in the dedicated visionOS simulator](Documentation/Media/THREADS-field.png)

## The instrument

- Ten playable foreground strings, with **Nocturne** (D minor), **Dawn** (D major) and **Drift** (A minor) pentatonic moods in Sound. Fingertip crossings create notes; speed controls excitation. A light pulse and a damped standing wave respond to the same event.
- Pinch a small light bead and pull up to 18 cm to stretch. Tension raises pitch by up to roughly 7.6 semitones. Release returns the string to rest and produces an acoustic response. Native gaze-and-pinch tap and drag offer a fallback.
- Sweep an open palm near the foreground strings for a quiet harmonic wave. A short relaxed sweep is enough; there is no exact target point. Hold both open hands near its center, 16–42 cm apart, for 0.85 seconds to invite a chord. A four-second cooldown prevents repeated chords. The distant architectural filaments are decorative.
- **Echo trails** adds two fading replies to each note, without recursively recording them. **Tools → Start guided play** highlights an eight-note phrase one bead at a time. **Playing distance → Closer / Original** adjusts reach while preserving the loop. Live hand status and **Restart hand tracking** help recover a lost session.
- Record up to twelve seconds of musical events, then overdub by playing live. Stop early, pause/resume, or clear. No microphone recording. Loops live for the current visit to the field.
- Quiet spatial notes and slow architectural breathing continue when idle. Sound contains volume and Ambient; Tools contains Recenter, Play controls, Help, Minimize and Reset. Recenter preserves the loop. Clear has a ten-second Undo; replacing, resetting or exiting with a loop has an explicit cancel choice.

## Architecture

| Area | Implementation |
| --- | --- |
| App / UI | SwiftUI welcome window, Full ImmersiveSpace, movable native control window with popovers/alerts, RealityView recovery attachment, native targeted tap/drag gestures |
| Scene | Five large twisted lattices, two sweeping overhead ribbons, a small sixth instrument anchor, dark gallery, ceiling ribs, distant wall markers, circular light pools |
| Geometry | 520 decorative filaments batched into 11 lattice/ribbon meshes; 10 interactive strings use 140 pooled, shared-mesh segments. No per-frame mesh generation |
| Motion | Damped mathematical vibration, smooth bounded tension displacement, proximity highlights, propagating pulses, reduced-motion support |
| Tracking | ARKit HandTrackingProvider and WorldTrackingProvider; tracked joints only, trajectory-gap rejection, debounce, contact rearming, pinch hysteresis, lost-hand release |
| Audio | Fractional-delay Karplus–Strong model with quiet body/glass partials; ten deterministic mono buffers prepared off the main thread; 24 pooled voices, varispeed, world-positioned AVAudioEnvironmentNode, warm hall reverb, peak limiter |
| Spatialization | Physical build uses HRTF; simulator uses the deterministic spherical-head spatial algorithm. Both use actual source positions. The physical build follows the tracked head; the simulator uses a fixed seated listener. No random panning |
| Loop | Bounded timestamped events; monotonic playback; pause keeps its playhead; old notes are skipped after frame stalls; loop playback is not recorded recursively |
| Privacy | Hand data stays in memory on device. No tracking persistence, networking, analytics, microphone, external assets, or dependencies |

Audio and tracking are separate services. Only ten strings participate in contact calculations. Rendering updates from RealityKit's scene-update event, while SwiftUI status refreshes at about 10 Hz. The playing region is placed relative to the initial head position and can be recentered using Tools → Recenter. It does not follow every head movement.

## Files

- `THREADS/App`: app entry, shared experience state and behavior.
- `THREADS/Core`: finite-segment contact geometry, excitation, scale, and loop timing.
- `THREADS/Scene`: procedural mesh builder, architecture, pooled interactive geometry.
- `THREADS/Interaction`: hand permission, joint tracking, world/head tracking, interruption status.
- `THREADS/Audio`: deterministic acoustic synthesis and the positional audio graph.
- `THREADS/UI`: welcome, secondary controls, onboarding, native gesture fallback.
- `THREADSTests`: geometry, gesture, motion, synthesis, tuning, loops, state and real scene construction.
- `THREADSUITests`: simulator entry, note controls, stretch/wave/resonance, recording, clear/reset, exit and reentry.

## Verification and headset use

See [verification results](Documentation/VERIFICATION.md), [Vision Pro setup](Documentation/RUN_ON_VISION_PRO.md), [physical-device checklist](Documentation/DEVICE_TEST_CHECKLIST.md), [toolbar UX decisions](Documentation/TOOLBAR_UX.md), and [portfolio overview](Documentation/PORTFOLIO.md).

The [1.1 update notes](Documentation/UPDATE_1_1.md) describe the open-palm wave correction, single-instance control window and four new features. The window uses visionOS 26's `Window` scene so repeated open requests reuse one instance.

The physical-device build compiles ARKit code that the simulator cannot execute. Successful compilation does **not** establish headset hand-tracking accuracy, comfort, acoustic localization, motion-to-sound latency, or sustained device performance. These require testing while wearing Apple Vision Pro.

## Command-line use

From this project folder, with Xcode selected:

```sh
xcodebuild -project THREADS.xcodeproj -scheme THREADS \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

xcodebuild -project THREADS.xcodeproj -scheme THREADS \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' \
  -derivedDataPath build -parallel-testing-enabled NO \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

If multiple simulators have the same name, use a destination ID from `xcrun simctl list devices available`. Run arguments: `--demo` opens the field and plays a short introduction; `--verify` runs a timed interaction/loop/reset/exit scenario and writes `THREADS-verification.json` to the app's Documents folder. Normal launch opens the welcome window.

Deployment target: visionOS 26.0, required for the native spatial presentations and breakthrough behavior. Verified toolchain and runtime versions are recorded in the verification document. Audio-session activation uses the asynchronous API on visionOS 27 and an off-main-thread compatibility path on earlier supported versions.

## Public-source privacy

No API keys or external service credentials are needed. Local signing configuration, raw Xcode result bundles, build output and personal machine state are excluded from this repository. See [PRIVACY.md](PRIVACY.md) and [the publication audit](Documentation/SecurityAudit.md).
