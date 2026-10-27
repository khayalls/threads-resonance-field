# THREADS — Resonance Field

**An instrument made of light.**

THREADS explores how a spatial interface can be experienced as a material rather than a menu. Suspended luminous filaments form a dark architectural chamber; a smaller group of reachable strings becomes a quiet, tactile instrument. A fingertip crossing produces an acoustic note, physical-looking vibration, and a wave of light from one shared excitation event.

The interaction vocabulary grows from a simple action: brush to pluck, pinch and pull to change tension, sweep an open palm for a harmonic wave, and bring both open hands together near the center to invite resonance. A twelve-second event loop lets a brief gesture become a continuing musical layer. A pentatonic tuning makes free exploration musically coherent.

The prototype is built natively with SwiftUI, RealityKit, ARKit and AVFAudio. Its chamber is procedural three-dimensional geometry, not an image backdrop. Decorative filaments are batched efficiently, while ten playable strings use pooled geometry and trajectory-based contact detection. A fractional-delay acoustic string model feeds a positional audio environment with room reflections and warm reverberation.

The design balances a gallery-scale composition with a seated-scale interaction zone. Restrained light, slow transitions and contextual hints keep attention on the instrument. A small optional control surface supplies reliable recording, reset and exit controls.

**Prototype status:** native application, simulator interaction flow, procedural scene, audio signal generation, and automated behavior tests are documented in the accompanying verification report. Physical hand tracking, spatial listening quality, comfort and sustained Apple Vision Pro performance remain to be evaluated with a person wearing the headset.

**Next research questions:** How readily do people discover plucking without instruction? Which tension-to-pitch mapping feels most material? Does a shared light-and-sound response increase perceived agency? What reach, fatigue and auditory localization differences appear between seated participants?
