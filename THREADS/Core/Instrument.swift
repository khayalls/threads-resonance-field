import Foundation
import simd

typealias V3 = SIMD3<Float>

enum Instrument {
    static let midi = [50, 53, 55, 57, 60, 62, 65, 67, 69, 72]
    static let names = ["D3", "F3", "G3", "A3", "C4", "D4", "F4", "G4", "A4", "C5"]
    static let count = midi.count
    static func frequency(_ index: Int) -> Double {
        440 * pow(2, Double(midi[index] - 69) / 12)
    }
    static func endpoints(_ index: Int) -> (V3, V3) {
        let x = Float(index) * 0.105 - 0.4725
        return (V3(x, -0.68, -0.56), V3(x * 0.86, 0.38 + 0.06 * cos(Float(index)), -0.82))
    }
    static func center(_ index: Int) -> V3 {
        let (a, b) = endpoints(index)
        return simd_mix(a, b, V3(repeating: 0.47))
    }
}

enum Soundscape: String, CaseIterable, Identifiable {
    case nocturne = "Nocturne", dawn = "Dawn", drift = "Drift"
    var id: String { rawValue }
    var midi: [Int] {
        switch self {
        case .nocturne: return Instrument.midi
        case .dawn: return [50, 52, 54, 57, 59, 62, 64, 66, 69, 71]
        case .drift: return Instrument.midi.map { $0 - 5 }
        }
    }
    var detail: String {
        switch self {
        case .nocturne: return "D minor · quiet and reflective"
        case .dawn: return "D major · open and luminous"
        case .drift: return "A minor · deeper and unhurried"
        }
    }
    func name(_ index: Int) -> String {
        let note = midi[index]
        return ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][note % 12] + String(note / 12 - 1)
    }
    func rate(_ index: Int) -> Float { pow(2, Float(midi[index] - Instrument.midi[index]) / 12) }
}

enum PlayingReach: String, CaseIterable, Identifiable {
    case relaxed = "Closer", original = "Original"
    var id: String { rawValue }
    var offset: V3 { self == .relaxed ? [0, -0.10, 0.14] : .zero }
}

struct GuidedPhrase {
    static let notes = [0, 3, 4, 7, 5, 4, 3, 0]
    private(set) var progress = 0
    var target: Int? { progress < Self.notes.count ? Self.notes[progress] : nil }
    var complete: Bool { target == nil }
    mutating func play(_ string: Int) { if string == target { progress += 1 } }
}

struct EchoTrail {
    private var pending: [NoteEvent] = []
    mutating func append(string: Int, strength: Float, tension: Float, at time: Double) {
        // Bounded voices, a finite two-note tail, and no feedback into the recorder.
        guard pending.count <= 44 else { return }
        for (delay, gain) in [(0.32, Float(0.38)), (0.64, Float(0.16))] {
            pending.append(NoteEvent(time: time + delay, string: string, strength: strength * gain, tension: tension))
        }
    }
    mutating func tick(at time: Double) -> [NoteEvent] {
        let due = pending.filter { $0.time <= time && time - $0.time < 0.15 }
        pending.removeAll { $0.time <= time }
        return due
    }
    mutating func clear() { pending.removeAll() }
}

enum Geometry {
    static func closestPoint(_ p: V3, _ a: V3, _ b: V3) -> V3 {
        let d = b - a
        let t = max(0, min(1, simd_dot(p - a, d) / max(0.000001, simd_length_squared(d))))
        return a + d * t
    }
    /// Closest distance between two finite segments; handles parallel and degenerate inputs.
    static func segmentDistance(_ p1: V3, _ q1: V3, _ p2: V3, _ q2: V3) -> Float {
        let d1 = q1 - p1, d2 = q2 - p2, r = p1 - p2
        let a = simd_dot(d1, d1), e = simd_dot(d2, d2), f = simd_dot(d2, r)
        var s: Float = 0, t: Float = 0
        if a < 0.000001 && e < 0.000001 { return simd_distance(p1, p2) }
        if a < 0.000001 { t = max(0, min(1, f / e)) }
        else {
            let c = simd_dot(d1, r)
            if e < 0.000001 { s = max(0, min(1, -c / a)) }
            else {
                let b = simd_dot(d1, d2), den = a * e - b * b
                if abs(den) > 0.000001 { s = max(0, min(1, (b * f - c * e) / den)) }
                t = (b * s + f) / e
                if t < 0 { t = 0; s = max(0, min(1, -c / a)) }
                else if t > 1 { t = 1; s = max(0, min(1, (b - c) / a)) }
            }
        }
        return simd_distance(p1 + d1 * s, p2 + d2 * t)
    }
}

struct StringMotion {
    var amplitude: Float = 0
    var phase: Float = 0
    var pull = V3.zero
    var targetPull = V3.zero
    var energy: Float = 0
    var pulse: Float = 1.1
    var proximity: Float = 0
    var lastPluck: Double = -100
    var grabbed = false

    mutating func excite(_ strength: Float) {
        amplitude = min(0.038, amplitude + strength * 0.032)
        energy = min(1, energy + strength)
        pulse = 0
    }
    mutating func step(_ delta: Float, reducedMotion: Bool = false) {
        let dt = min(0.05, max(0, delta))
        amplitude *= exp(-dt * 3.3)
        energy *= exp(-dt * 1.8)
        phase += dt * 36
        pulse += dt * 0.85
        if !grabbed { targetPull *= exp(-dt * 8) }
        pull += (targetPull - pull) * (1 - exp(-dt * 20))
        if reducedMotion { amplitude = 0 }
    }
    func point(_ a: V3, _ b: V3, t: Float) -> V3 {
        let envelope = sin(.pi * t)
        let displacement = amplitude * envelope * sin(phase + t * 4)
        return a + (b - a) * t + pull * envelope + V3(displacement, 0, displacement * 0.3)
    }
}

struct CrossingGate {
    private(set) var previous: V3?
    private(set) var previousTime: Double = 0
    private var cooldown = Array(repeating: -100.0, count: Instrument.count)
    private var armed = Array(repeating: true, count: Instrument.count)

    mutating func reset() { self = CrossingGate() }
    mutating func sample(point: V3, at time: Double, excluded: Int? = nil) -> [(Int, Float)] {
        defer { previous = point; previousTime = time }
        guard let old = previous else { return [] }
        let dt = time - previousTime
        guard dt > 0.001, dt < 0.12, simd_distance(point, old) < 0.20 else { return [] }
        let velocity = simd_distance(point, old) / Float(dt)
        var hits: [(Int, Float)] = []
        for i in 0..<Instrument.count {
            let (a, b) = Instrument.endpoints(i)
            let distance = simd_distance(point, Geometry.closestPoint(point, a, b))
            if distance > 0.048 { armed[i] = true }
            guard i != excluded, armed[i], time - cooldown[i] > 0.18,
                  velocity > 0.035, velocity < 4,
                  Geometry.segmentDistance(old, point, a, b) < 0.028 else { continue }
            // Reject motion along the strand and tracking jitter at a stationary contact.
            let direction = simd_normalize(b - a)
            let perpendicular = point - old - direction * simd_dot(point - old, direction)
            guard simd_length(perpendicular) > 0.0003 else { continue }
            hits.append((i, min(1, max(0.18, velocity * 0.65))))
            cooldown[i] = time
            armed[i] = false
        }
        return hits
    }
}

struct WaveGate {
    private var previous: V3?
    private var previousTime: Double = 0
    private var sweepOrigin: V3?
    private var lastTrigger: Double = -100

    mutating func reset() { self = WaveGate() }
    mutating func sample(palm: V3, open: Bool, at time: Double) -> Float? {
        defer { previous = open ? palm : nil; previousTime = time }
        guard open, let old = previous else { sweepOrigin = nil; return nil }
        let dt = time - previousTime, distance = simd_distance(old, palm)
        guard dt > 0.001, dt < 0.20, distance < 0.20 else { sweepOrigin = nil; return nil }
        let speed = distance / Float(dt)
        let near = (0..<Instrument.count).contains { i in
            let (a, b) = Instrument.endpoints(i)
            return Geometry.segmentDistance(old, palm, a, b) < 0.18
        }
        guard near, speed > 0.035, speed < 2.5 else { sweepOrigin = nil; return nil }
        if sweepOrigin == nil { sweepOrigin = old }
        // Net displacement prevents tiny back-and-forth tracking jitter from accumulating a wave.
        guard simd_distance(sweepOrigin!, palm) >= 0.035, time - lastTrigger >= 0.8 else { return nil }
        sweepOrigin = palm; lastTrigger = time
        return min(0.75, 0.3 + speed * 0.45)
    }
}

struct NoteEvent: Codable, Equatable {
    var time: Double
    var string: Int
    var strength: Float
    var tension: Float
}

struct PerformanceLoop {
    enum State: String { case empty, recording, playing, paused }
    private(set) var state: State = .empty
    private(set) var events: [NoteEvent] = []
    private(set) var duration: Double = 12
    private var origin: Double = 0
    private var lastElapsed: Double = -0.001
    private var pausedElapsed: Double = 0

    var hasEvents: Bool { !events.isEmpty }
    mutating func record(at time: Double) {
        events.removeAll(keepingCapacity: true); duration = 12; origin = time
        state = .recording; lastElapsed = -0.001; pausedElapsed = 0
    }
    mutating func append(string: Int, strength: Float, tension: Float, at time: Double) {
        guard state == .recording, time - origin < 12, events.count < 512 else { return }
        events.append(NoteEvent(time: max(0, time - origin), string: string, strength: strength, tension: tension))
    }
    mutating func stop(at time: Double) {
        guard state == .recording else { return }
        duration = min(12, max(1, time - origin))
        state = events.isEmpty ? .empty : .playing
        origin = time; lastElapsed = -0.001
    }
    mutating func toggle(at time: Double) {
        if state == .playing { pausedElapsed = time - origin; state = .paused }
        else if state == .paused { origin = time - pausedElapsed; state = .playing; lastElapsed = pausedElapsed }
    }
    mutating func clear() { self = PerformanceLoop() }
    func progress(at time: Double) -> Double {
        if state == .recording { return min(1, max(0, (time - origin) / 12)) }
        let elapsed = state == .paused ? pausedElapsed : time - origin
        return state == .empty ? 0 : elapsed.truncatingRemainder(dividingBy: duration) / duration
    }
    mutating func tick(at time: Double) -> [NoteEvent] {
        if state == .recording && time - origin >= 12 { stop(at: time) }
        guard state == .playing else { return [] }
        let elapsed = time - origin
        let start = max(-0.001, lastElapsed)
        defer { lastElapsed = elapsed }
        // Do not burst old notes after a long frame stall or app interruption.
        let lower = max(start, elapsed - 0.20)
        var due: [NoteEvent] = []
        for cycle in max(0, Int(floor(max(0, lower) / duration)))...max(0, Int(floor(elapsed / duration))) {
            for event in events {
                let t = Double(cycle) * duration + event.time
                if t > lower && t <= elapsed { due.append(event) }
            }
        }
        return due
    }
}
