# Run THREADS on Apple Vision Pro

1. Open `THREADS.xcodeproj` in Xcode. Choose the THREADS scheme.
2. Add your Apple Account in Xcode Settings → Accounts if necessary. In THREADS target → Signing & Capabilities, enable automatic signing, choose your own Team, and use a unique bundle identifier if requested. Do not enter credentials into scripts or share them in chat.
3. Pair Apple Vision Pro with Xcode / Device Hub on the same network. Enable Developer Mode on the headset if prompted. Follow any restart and developer-trust prompts on the headset.
4. Select your Apple Vision Pro as the run destination. Build and Run. This prototype is not published.
5. Sit comfortably with clear space in front of your hands. Start at a modest sound level. Choose **Enter the Field**, then allow hand tracking when visionOS asks.
6. The instrument is placed in front of your initial head position. **Tools → Recenter** repositions it at your current position without clearing a loop. **Reset field** also silences notes and clears the loop. Brush a fingertip sideways across a thread. Use a small bead for pinch-and-pull stretching.
7. For a wave, open your fingers and sweep a palm a few centimeters near the ten foreground strings. Watch the tracked-hand/open-palm status; use Tools → Restart hand tracking if tracking stops. Tools → Playing distance → Closer lowers and brings the instrument toward you. For resonance, hold both open palms near the center, comfortably separated, for about one second. Help describes the gesture.
8. If hand access is denied or tracking is unavailable, gaze at a bead and pinch to pluck, or pinch and drag to stretch. **Tools → Play controls** supplies explicit controls for all effects. Exit remains visible when the control panel is collapsed. The Digital Crown also provides the standard system escape from full immersion.

Sound offers Nocturne / Dawn / Drift and optional Echo trails. Tools → Start guided play lights an eight-note phrase. These modes preserve the current visit's loop.

## Optional local signing configuration

`Configuration/LocalSigning.xcconfig.example` illustrates local signing values. If you copy it to `LocalSigning.xcconfig`, assign that file as the app target's configuration in Xcode, or continue using Xcode's normal Signing settings. This optional file is ignored by Git and is not required for simulator builds. No personal Team or device identifier is included in this project.

## Version notes

The project has a visionOS 26.0 deployment target and uses public Apple frameworks only. Both simulator and physical-target compilation must pass before installation. An unsigned generic-device build cannot be installed by itself; Xcode must create a signed build with your account. Testing on older supported OS versions remains a separate compatibility check.
