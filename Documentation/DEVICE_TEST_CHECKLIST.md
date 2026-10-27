# Physical-device test checklist

Status: pending a human wearing Apple Vision Pro. Do not infer these results from simulator screenshots, synthetic hand samples, successful builds, installation, or process launch.

## Entry and comfort

- [ ] Signed installation succeeds; the welcome window opens correctly.
- [ ] Enter / cancel / re-enter Full Immersion work; the chamber fades in without a flash.
- [ ] Strings lie within comfortable seated reach; Tools → Recenter correctly recenters after moving the chair or turning.
- [ ] The native dock initially opens within comfortable view. It can be repositioned, minimized, closed and restored using Show controls. Exit remains readable. Gaze-and-pinch hits the intended control.
- [ ] Looking up, down, sideways and behind reveals a coherent 360-degree space.
- [ ] Hands are visible, the virtual floor feels stable, and ten minutes of use are comfortable.

## Toolbar safeguards and access

- [ ] Sound opens and closes predictably; slider and precise level buttons both work.
- [ ] Native hover and focus feedback are clear, including with hands resting in the lap.
- [ ] Clear → Undo restores the loop paused. Recenter preserves the current performance.
- [ ] Replacement, Reset and Exit with a performance show a cancel choice that preserves it.
- [ ] The loop status does not shift the main action row when recording starts or stops.
- [ ] Test VoiceOver, Switch Control, keyboard navigation and large accessibility text. Panels scroll without losing actions.

## Tracking and interaction

- [ ] Allow hand permission: fingertip brush plucks the correct thread.
- [ ] Slow and quick crossings produce a useful intensity range; resting fingers do not produce repeated notes.
- [ ] Both hands work independently. Entering the tracking area does not create a burst of accidental notes.
- [ ] Pinch near a bead captures the intended string. Pulling changes shape and sound; release returns smoothly.
- [ ] Gaze-and-pinch tap and native drag work when raw hand tracking is unavailable.
- [ ] Open-palm movement produces a wave without requiring large arm movements.
- [ ] Two open hands near the center trigger one chord after a short hold; ordinary pinching does not.
- [ ] Hands leaving view release every held string. Reacquisition does not use an old fingertip trajectory.
- [ ] Deny/revoke hand access: the app explains the fallback, stays responsive, and still exits reliably.

## Audio and loop

- [ ] All ten notes sound acoustic, tuned and free of clicks, harshness, clipping or bursts.
- [ ] Faster plucks sound stronger; stretched strings audibly rise in pitch and brighten.
- [ ] Sound is perceived at the strand; turning the head changes localization consistently.
- [ ] Front/back and elevated sources sound plausible on the built-in speakers and optional headphones.
- [ ] Reverb feels warm and balanced at low and high volume; Ambient Off suppresses future idle notes.
- [ ] Recording stops at twelve seconds or on Stop. Playback timing, pause/resume, layering and Clear work.
- [ ] Reset silences current voices and clears the loop. Exit leaves no continuing audio.
- [ ] System interruption / removal / resume does not leave stuck notes or stale interaction state.

## Performance and access

- [ ] Use Instruments RealityKit / Metal tools on the physical device to inspect frame time and rendering cost.
- [ ] Observe sustained performance and thermal behavior for at least ten minutes while playing with both hands.
- [ ] Check motion-to-light and motion-to-sound latency perceptually; use a measured capture before quoting a latency value.
- [ ] Verify the accessibility Reduce Motion setting reduces strand vibration and environmental motion.
- [ ] Test normal launch on the headset's installed OS; compatibility beyond the verified build toolchain is not assumed.

Record device model / OS, result, observed problem, and change needed for each failure. No raw hand data needs to be stored.
