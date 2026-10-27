import Foundation

enum AcousticSynthesis {
    static let sampleRate = 48_000.0
    /// Damped delay-line string with a felt attack and a quiet, slightly inharmonic glass overtone.
    /// Deterministic, local synthesis. Never called on the audio render thread or interaction path.
    static func samples(frequency: Double, duration: Double = 5, seed: UInt64 = 42) -> [Float] {
        let count = Int(sampleRate * duration)
        let exactDelay = sampleRate / frequency - 0.5
        let integerDelay = max(4, Int(exactDelay))
        let fraction = Float(exactDelay - Double(integerDelay))
        let delay = integerDelay + 2
        var rng = seed
        func noise() -> Float {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Float(Double(rng >> 33) / Double(UInt32.max >> 1)) * 2 - 1
        }
        var ring = (0..<delay).map { _ in noise() * 0.65 }
        for _ in 0..<3 {
            let copy = ring
            for i in 0..<delay { ring[i] = (copy[i] + copy[(i + 1) % delay]) * 0.5 }
        }
        var output = [Float](repeating: 0, count: count)
        var cursor = 0
        var peak: Float = 0.00001
        let damping: Float = Float(pow(0.0015, 1 / (frequency * 4.4)))
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Fractional delay compensates the low-pass filter's half-sample group delay.
            // This keeps the physical-model body in tune with the exact harmonic partials.
            let a = (cursor + delay - integerDelay) % delay
            let b = (a + delay - 1) % delay, c = (b + delay - 1) % delay
            let first = ring[a] * (1 - fraction) + ring[b] * fraction
            let second = ring[b] * (1 - fraction) + ring[c] * fraction
            let value = (first + second) * 0.5 * damping
            ring[cursor] = value
            cursor = (cursor + 1) % delay
            let body = sin(2 * .pi * frequency * t) * exp(-t * 1.25) * 0.15
            let glass = sin(2 * .pi * frequency * 2.003 * t) * exp(-t * 2.7) * 0.035
            let attack = min(1, t / 0.006)
            let tail = min(1, (duration - t) / 0.15)
            output[i] = Float(attack * tail) * (value + Float(body + glass))
            peak = max(peak, abs(output[i]))
        }
        let gain = 0.76 / peak
        for i in output.indices { output[i] *= gain }
        return output
    }
    static func bank() -> [[Float]] {
        (0..<Instrument.count).map { samples(frequency: Instrument.frequency($0), seed: UInt64($0 + 91)) }
    }
}
