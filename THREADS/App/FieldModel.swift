import SwiftUI
import RealityKit
import QuartzCore
import Observation
import os

@MainActor @Observable
final class FieldModel {
    var immersive = false
    var transitioning = false
    var prepared = false
    var ambient = true
    var volume: Double = 0.65 { didSet { audio.volume = Float(volume) } }
    var showControls = true
    var soundReady = false
    var hint = "Brush across a thread. Listen to the light."
    var trackingStatus = "Preparing the field"
    var audioStatus = "Preparing acoustic strings"
    var lastNote = "D minor pentatonic"
    var loopState = PerformanceLoop.State.empty
    var loopProgress: Double = 0
    var loopCount = 0
    var loopDuration: Double = 12
    var canUndoLoopClear = false
    var error: String?
    var automaticEntryConsumed = false
    var welcomeIsOpen = false
    var controlsWindowOpen = false
    var controlsWindowRequested = false
    var soundscape = Soundscape.nocturne
    var echoEnabled = false { didSet { if !echoEnabled { echoes.clear() } } }
    var reach = PlayingReach.relaxed
    var guidedPhrase: GuidedPhrase?
    var handsStatus = "Waiting for hands"
    var guidedTarget: Int? { guidedPhrase?.target }
    @ObservationIgnored let chamber = ResonanceChamber()
    @ObservationIgnored let audio = SpatialInstrument()
    @ObservationIgnored let tracking = HandTracking()
    @ObservationIgnored var motions = Array(repeating: StringMotion(), count: Instrument.count)
    @ObservationIgnored private var loop = PerformanceLoop()
    @ObservationIgnored private var undoLoop: PerformanceLoop?
    @ObservationIgnored private var undoDeadline: Double = 0
    @ObservationIgnored private var gates = [CrossingGate(), CrossingGate()]
    @ObservationIgnored private var waveGates = [WaveGate(), WaveGate()]
    @ObservationIgnored private var echoes = EchoTrail()
    @ObservationIgnored private var samples: [HandSample?] = [nil, nil]
    @ObservationIgnored private var grabs: [Int?] = [nil, nil]
    @ObservationIgnored private var grabOrigins: [V3] = [.zero, .zero]
    @ObservationIgnored private var lastDragTone = Array(repeating: -100.0, count: Instrument.count)
    @ObservationIgnored private var lastContactTone = Array(repeating: -100.0, count: Instrument.count)
    @ObservationIgnored private var lastWave = -100.0
    @ObservationIgnored private var resonanceHold: Double = 0
    @ObservationIgnored private var lastResonance = -100.0
    @ObservationIgnored private var resonanceEnergy: Float = 0
    @ObservationIgnored private var started: Double = 0
    @ObservationIgnored private var lastActivity: Double = -100
    @ObservationIgnored private var lastAmbient: Double = 0
    @ObservationIgnored private var ambientIndex = 0
    @ObservationIgnored private var uiTime: Double = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var verificationTask: Task<Void, Never>?
    @ObservationIgnored private var frames: [Double] = []
    @ObservationIgnored private var counts: [String: Int] = [:]
    @ObservationIgnored private var transitions: [String] = []
    @ObservationIgnored private var built = false
    @ObservationIgnored private var running = false
    @ObservationIgnored var subscription: EventSubscription?
    @ObservationIgnored var onVerificationExit: (() async -> Void)?
    @ObservationIgnored private let logger = Logger(subsystem: "studio.threads.resonance", category: "Field")
    let automatic = ProcessInfo.processInfo.arguments.contains("--demo") || ProcessInfo.processInfo.arguments.contains("--verify")
    let verifying = ProcessInfo.processInfo.arguments.contains("--verify")

    func prepare() async {
        guard !prepared else { audio.resume(); return }
        await audio.prepare(); audioStatus = audio.status; prepared = audio.ready; soundReady = audio.ready
        if !prepared { error = audio.status }
    }
    func build() throws {
        guard !built else { return }
        try chamber.build(); built = true
    }
    func start() {
        guard !running else { return }
        running = true
        chamber.reach = reach
        chamber.prepareEntry(); audio.resume()
        started = CACurrentMediaTime(); immersive = true; lastAmbient = started
        tracking.onHand = { [weak self] side, sample in self?.receive(side: side, sample: sample) }
        tracking.onStatus = { [weak self] message in self?.trackingStatus = message }
        task = Task { [weak self] in await self?.tracking.start() }
        log("entered")
        if verifying { runVerification() }
        else if automatic { runDemo() }
    }
    func stop() {
        running = false
        immersive = false
        verificationTask?.cancel(); verificationTask = nil
        task?.cancel(); task = nil; tracking.stop(); audio.suspend()
        subscription?.cancel(); subscription = nil; loop.clear()
        echoes.clear(); clearHandInput(); guidedPhrase = nil
        controlsWindowRequested = false
        undoLoop = nil; canUndoLoopClear = false; soundReady = false
        loopState = .empty; loopProgress = 0; immersive = false
        log("exited"); writeReport()
    }
    func frame(delta: Double) {
        guard immersive else { return }
        let now = CACurrentMediaTime(), dt = Float(min(0.05, delta))
        if frames.count < 18_000 { frames.append(delta) }
        if let transform = tracking.deviceTransform() {
            if !chamber.isCalibrated { clearHandInput() }
            chamber.calibrate(to: transform); audio.listener(transform: transform)
        } else {
            var fallback = matrix_identity_float4x4; fallback.columns.3 = [0, 1.65, 0, 1]
            audio.listener(transform: fallback)
        }
        for side in 0..<2 {
            if let sample = samples[side], now - sample.timestamp > 0.25 { receive(side: side, sample: nil) }
        }
        for i in motions.indices {
            let (a, b) = Instrument.endpoints(i)
            let nearest = samples.compactMap { $0 }.map { simd_distance(chamber.localPoint($0.tip), Geometry.closestPoint(chamber.localPoint($0.tip), a, b)) }.min() ?? 1
            motions[i].proximity += (max(0, 1 - nearest / 0.12) - motions[i].proximity) * min(1, dt * 12)
            motions[i].step(dt, reducedMotion: chamber.reducedMotion)
        }
        if let left = samples[0], let right = samples[1], left.open, right.open {
            let lp = chamber.localPoint(left.palm), rp = chamber.localPoint(right.palm)
            let center = V3(0, -0.25, -0.50)
            let distance = simd_distance(lp, rp)
            if distance > 0.16, distance < 0.42, simd_distance((lp + rp) * 0.5, center) < 0.23 {
                resonanceHold += Double(dt)
                if resonanceHold > 0.85, now - lastResonance > 4 { resonance(); lastResonance = now; resonanceHold = 0 }
            } else { resonanceHold = 0 }
        } else { resonanceHold = 0 }
        resonanceEnergy *= exp(-dt * 0.7)
        for event in loop.tick(at: now) { pluck(event.string, strength: event.strength, tension: event.tension, source: "loop") }
        for event in echoes.tick(at: now) { pluck(event.string, strength: event.strength, tension: event.tension, source: "echo") }
        if ambient && now - lastAmbient > (now - lastActivity < 3 ? 6.5 : 4.2) {
            let sequence = [0, 4, 2, 7, 5, 3, 8, 1]
            let i = sequence[ambientIndex % sequence.count]; ambientIndex += 1; lastAmbient = now
            let anchors: [V3] = [[-3.2, 2, -3.5], [3.3, 2.4, -4], [0, 3, -7.2], [-4.6, 2, 2.4], [4.7, 2, 2.8]]
            audio.play(string: i, strength: min(1, Float(now - started) / 4) * 0.65, tension: 0, position: anchors[ambientIndex % anchors.count], soft: true, soundscape: soundscape)
            motions[i].energy = max(motions[i].energy, 0.13)
        }
        chamber.animate(motions: motions, time: Float(now - started), fade: min(1, Float(now - started) / 1.6), resonance: resonanceEnergy, guidedTarget: guidedTarget)
        if now - uiTime > 0.10 {
            uiTime = now; syncLoopUI(at: now)
            if canUndoLoopClear && now >= undoDeadline { undoLoop = nil; canUndoLoopClear = false }
            audioStatus = audio.status; soundReady = audio.ready
            let visible = samples.compactMap { $0 }
            handsStatus = visible.isEmpty ? "Waiting for hands · face the ten foreground strings" :
                (visible.count == 2 ? "Both hands tracked" : "One hand tracked") + (visible.contains(where: { $0.open }) ? " · open palm ready" : " · open your fingers to wave")
        }
    }
    func pluck(_ i: Int, strength: Float = 0.65, tension: Float = 0, source: String = "touch") {
        guard motions.indices.contains(i), immersive else { return }
        let now = CACurrentMediaTime()
        if source == "touch" {
            guard now - lastContactTone[i] >= 0.08 else { return }
            lastContactTone[i] = now
        }
        motions[i].excite(strength); motions[i].lastPluck = now
        audio.play(string: i, strength: strength, tension: tension, position: chamber.worldPoint(Instrument.center(i)), soundscape: soundscape)
        if source != "loop" && source != "echo" { loop.append(string: i, strength: strength, tension: tension, at: now); lastActivity = now }
        if echoEnabled && source != "echo" { echoes.append(string: i, strength: strength, tension: tension, at: now) }
        if source != "echo" { lastNote = "\(soundscape.name(i))  ·  \(source == "loop" ? "loop" : "resonating")" }
        if counts["touch", default: 0] == 0 && source == "touch" { hint = "Pinch a light bead and pull gently to change its tension." }
        counts[source, default: 0] += 1
        if ["touch", "demo", "stretch"].contains(source), guidedPhrase != nil {
            guidedPhrase?.play(i)
            hint = guidedPhrase?.complete == true ? "Phrase complete. Make it your own, or try again in Tools." : "Follow the brighter bead. Take your time."
        }
    }
    func receive(side: Int, sample: HandSample?) {
        guard (0..<2).contains(side) else { return }
        guard let sample else {
            if let i = grabs[side] { release(i) }
            samples[side] = nil; grabs[side] = nil; gates[side].reset(); waveGates[side].reset(); return
        }
        guard immersive else { return }
        samples[side] = sample
        let tip = chamber.localPoint(sample.tip), thumb = chamber.localPoint(sample.thumb)
        let pinch = simd_distance(tip, thumb)
        if let i = grabs[side] {
            if !sample.pinchAvailable || pinch > 0.041 { release(i); grabs[side] = nil; gates[side].reset() }
            else {
                drag(i, displacement: tip - grabOrigins[side])
            }
        } else if sample.pinchAvailable && pinch < 0.023 {
            let candidate = (0..<Instrument.count).filter { !motions[$0].grabbed }.min { simd_distance(tip, Instrument.center($0)) < simd_distance(tip, Instrument.center($1)) }
            if let i = candidate, simd_distance(tip, Instrument.center(i)) < 0.065 {
                grabs[side] = i; grabOrigins[side] = tip; motions[i].grabbed = true; gates[side].reset()
                pluck(i, strength: 0.28, source: "stretch")
            }
        }
        if !sample.pinchAvailable || pinch > 0.035 {
            for (i, strength) in gates[side].sample(point: tip, at: sample.timestamp, excluded: grabs[side]) {
                if !motions[i].grabbed { pluck(i, strength: strength) }
            }
        } else { gates[side].reset() }
        let palm = chamber.localPoint(sample.palm)
        if let strength = waveGates[side].sample(palm: palm, open: sample.open, at: sample.timestamp),
           sample.timestamp - lastWave > 0.55 {
            wave(strength: strength); lastWave = sample.timestamp
        }
    }
    func drag(_ i: Int, displacement: V3) {
        guard motions.indices.contains(i) else { return }
        motions[i].grabbed = true
        let distance = simd_length(displacement)
        motions[i].targetPull = distance > 0.18 ? displacement / distance * 0.18 : displacement
        motions[i].energy = max(motions[i].energy, min(1, distance * 5))
        let now = CACurrentMediaTime()
        if now - lastDragTone[i] > 0.3, distance > 0.015 {
            let tension = simd_length(motions[i].targetPull)
            audio.play(string: i, strength: 0.27, tension: tension, position: chamber.worldPoint(Instrument.center(i) + motions[i].pull), soundscape: soundscape)
            loop.append(string: i, strength: 0.27, tension: tension, at: now)
            lastDragTone[i] = now
        }
    }
    func release(_ i: Int) {
        guard motions.indices.contains(i) else { return }
        let tension = simd_length(motions[i].targetPull)
        motions[i].grabbed = false; motions[i].targetPull = .zero
        pluck(i, strength: 0.3 + tension * 2, tension: tension, source: "stretch")
    }
    func wave(strength: Float = 0.4) {
        for i in motions.indices {
            motions[i].excite(strength * 0.45); motions[i].phase += Float(i) * 0.5
        }
        for i in [0, 4, 7] { pluck(i, strength: strength * 0.45, source: "wave") }
        hint = "Let both open hands rest near the center to invite a chord."
        log("wave")
    }
    func resonance() {
        resonanceEnergy = 1
        for i in motions.indices { motions[i].excite(0.48); motions[i].phase = Float(i) * 0.4 }
        for i in [0, 3, 5, 7] { pluck(i, strength: 0.45, source: "resonance") }
        hint = "The field is listening. Take your time."
        log("resonance")
    }
    func record() {
        undoLoop = nil; canUndoLoopClear = false
        if loop.state == .recording { loop.stop(at: CACurrentMediaTime()); log("record_stopped") }
        else { loop.record(at: CACurrentMediaTime()); log("record_started") }
        syncLoopUI()
    }
    private func syncLoopUI(at now: Double = CACurrentMediaTime()) {
        loopState = loop.state; loopProgress = loop.progress(at: now); loopCount = loop.events.count; loopDuration = loop.duration
    }
    func toggleLoop() { loop.toggle(at: CACurrentMediaTime()); syncLoopUI(); log("loop_\(loop.state.rawValue)") }
    func clearLoop() {
        loop.clear(); undoLoop = nil; canUndoLoopClear = false; syncLoopUI(); log("loop_cleared")
    }
    func clearLoopWithUndo() {
        guard loop.hasEvents, loop.state != .recording else { return }
        let now = CACurrentMediaTime()
        var saved = loop
        if saved.state == .playing { saved.toggle(at: now) }
        undoLoop = saved; undoDeadline = now + 10
        loop.clear(); syncLoopUI(); canUndoLoopClear = true; log("loop_cleared_with_undo")
    }
    func undoLoopClear() {
        guard canUndoLoopClear, CACurrentMediaTime() < undoDeadline, let saved = undoLoop else { return }
        loop = saved; undoLoop = nil; canUndoLoopClear = false; syncLoopUI(); log("loop_restored_paused")
    }
    func recenter() {
        clearHandInput()
        if let head = tracking.deviceTransform() { chamber.calibrate(to: head, force: true) }
        else {
            var seated = matrix_identity_float4x4; seated.columns.3 = [0, 1.65, 0, 1]
            chamber.calibrate(to: seated, force: true)
        }
        log("recentered")
    }
    func reset() {
        clearLoop(); audio.silence(); motions = Array(repeating: StringMotion(), count: Instrument.count)
        samples = [nil, nil]; grabs = [nil, nil]; gates = [CrossingGate(), CrossingGate()]
        echoes.clear(); guidedPhrase = nil
        lastDragTone = Array(repeating: -100, count: Instrument.count)
        lastNote = soundscape.detail; resonanceEnergy = 0; resonanceHold = 0
        recenter()
        hint = "Brush across a thread. Listen to the light."; log("reset")
    }
    func pause() {
        echoes.clear(); clearHandInput(); audio.suspend()
        task?.cancel(); task = nil; tracking.stop()
        if loop.state == .playing { toggleLoop() }
    }
    func resume() {
        audio.resume()
        if running && immersive && task == nil { restartTracking() }
    }
    func restartTracking() {
        guard immersive else { return }
        task?.cancel(); clearHandInput(); tracking.stop()
        trackingStatus = "Restarting hand tracking…"
        task = Task { [weak self] in await self?.tracking.start() }
    }
    private func clearHandInput() {
        samples = [nil, nil]; grabs = [nil, nil]
        gates = [CrossingGate(), CrossingGate()]; waveGates = [WaveGate(), WaveGate()]
        for i in motions.indices { motions[i].grabbed = false; motions[i].targetPull = .zero }
        lastWave = -100; resonanceHold = 0; handsStatus = "Waiting for hands"
        lastContactTone = Array(repeating: -100, count: Instrument.count)
    }
    func setReach(_ value: PlayingReach) {
        clearHandInput(); reach = value; chamber.reach = value
        hint = "The ten foreground strings are your instrument. Brush or wave near them."
    }
    func startGuidedPlay() { guidedPhrase = GuidedPhrase(); hint = "Follow the brighter bead. Take your time." }
    func stopGuidedPlay() { guidedPhrase = nil; hint = "Play freely. The field is listening." }
    func requestControls(_ open: () -> Void) {
        guard immersive, !controlsWindowOpen, !controlsWindowRequested else { return }
        controlsWindowRequested = true; open()
    }
    func controlsAppeared() { controlsWindowOpen = true; controlsWindowRequested = false }
    func controlsDisappeared() { controlsWindowOpen = false; controlsWindowRequested = false }
    private func log(_ event: String) { transitions.append(event); logger.info("THREADS \(event, privacy: .public)") }

    private func runDemo() {
        verificationTask = Task { [weak self] in
            for i in [0, 3, 5, 7, 4, 8, 2, 6, 9, 5] {
                try? await Task.sleep(for: .seconds(0.7)); guard !Task.isCancelled else { return }
                self?.pluck(i, source: "demo")
            }
        }
    }
    private func runVerification() {
        verificationTask = Task { [weak self] in
            guard let self else { return }
            func delay(_ seconds: Double) async -> Bool {
                do { try await Task.sleep(for: .seconds(seconds)); return !Task.isCancelled } catch { return false }
            }
            guard await delay(2) else { return }
            self.record()
            for i in 0..<10 {
                self.pluck(i, strength: 0.55, source: "demo")
                guard await delay(0.38) else { return }
            }
            self.drag(4, displacement: [0.12, 0.02, 0.05]); self.log("stretch_began")
            guard await delay(1.2) else { return }
            self.release(4); self.log("stretch_released")
            self.wave(); guard await delay(1.2) else { return }; self.resonance()
            guard await delay(5) else { return }
            if self.loop.state == .recording { self.record() }
            self.log("loop_playback_observed")
            guard await delay(3) else { return }; self.toggleLoop()
            guard await delay(0.5) else { return }; self.toggleLoop()
            guard await delay(2) else { return }
            self.writeReport(); self.reset()
            guard await delay(1) else { return }
            self.log("exit_requested"); self.writeReport()
            await self.onVerificationExit?()
        }
    }
    func writeReport() {
        guard verifying else { return }
        let sorted = frames.sorted(), meter = audio.meter.snapshot()
        let report: [String: Any] = [
            "environment": "visionOS Simulator", "decorativeStrands": chamber.decorativeCount,
            "interactiveStrings": Instrument.count, "latticeTriangles": chamber.triangleCount,
            "frames": frames.count, "meanFrameIntervalMS": frames.isEmpty ? 0 : frames.reduce(0, +) / Double(frames.count) * 1000,
            "p95FrameIntervalMS": sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] * 1000,
            "audioPeak": meter.0, "audioFrames": meter.1, "audioReady": audio.ready,
            "interactions": counts, "transitions": transitions, "loopEvents": loop.events.count,
            "loopState": loop.state.rawValue, "physicalHandTrackingVerified": false
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL.documentsDirectory.appending(path: "THREADS-verification.json"))
        }
    }
}
