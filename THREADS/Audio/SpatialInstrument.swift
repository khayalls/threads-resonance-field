import AVFoundation
import simd

final class AudioMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0
    private var frames: UInt64 = 0
    func consume(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        var value: Float = 0
        for c in 0..<Int(buffer.format.channelCount) {
            for i in 0..<Int(buffer.frameLength) { value = max(value, abs(data[c][i])) }
        }
        lock.lock(); peak = max(peak, value); frames += UInt64(buffer.frameLength); lock.unlock()
    }
    func snapshot() -> (Float, UInt64) {
        lock.lock(); defer { lock.unlock() }; return (peak, frames)
    }
}

@MainActor
final class SpatialInstrument {
    private let engine = AVAudioEngine()
    private let space = AVAudioEnvironmentNode()
    private let reverb = AVAudioUnitReverb()
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    private var players: [AVAudioPlayerNode] = []
    private var rates: [AVAudioUnitVarispeed] = []
    private var sources: [AVAudioMixerNode] = []
    private var buffers: [AVAudioPCMBuffer] = []
    private var cursor = 0
    private(set) var ready = false
    private(set) var status = "Preparing acoustic strings"
    let meter = AudioMeter()
    var volume: Float = 0.65 { didSet { engine.mainMixerNode.outputVolume = volume * 0.75 } }
    private var interruptionObserver: NSObjectProtocol?
    private var activationTask: Task<Void, Never>?

    func prepare() async {
        guard buffers.isEmpty else { resume(); return }
        let bank = await Task.detached(priority: .userInitiated) { AcousticSynthesis.bank() }.value
        let mono = AVAudioFormat(standardFormatWithSampleRate: AcousticSynthesis.sampleRate, channels: 1)!
        for samples in bank {
            let buffer = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(samples.count))!
            buffer.frameLength = buffer.frameCapacity
            samples.withUnsafeBufferPointer { source in
                buffer.floatChannelData![0].update(from: source.baseAddress!, count: source.count)
            }
            buffers.append(buffer)
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            if #available(visionOS 27.0, *) { _ = try await session.activate(options: []) }
            else { try await Task.detached { try session.setActive(true) }.value }
            engine.attach(space); engine.attach(reverb); engine.attach(limiter)
            let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
            let stereo = AVAudioFormat(standardFormatWithSampleRate: AcousticSynthesis.sampleRate, channelLayout: layout)
            engine.connect(space, to: reverb, format: stereo)
            engine.connect(reverb, to: limiter, format: stereo)
            engine.connect(limiter, to: engine.mainMixerNode, format: stereo)
            reverb.loadFactoryPreset(.largeHall2); reverb.wetDryMix = 24
            space.reverbParameters.enable = true
            space.reverbParameters.level = -18
            space.distanceAttenuationParameters.referenceDistance = 1
            space.distanceAttenuationParameters.maximumDistance = 18
            space.distanceAttenuationParameters.rolloffFactor = 0.7
            for _ in 0..<24 {
                let player = AVAudioPlayerNode(), rate = AVAudioUnitVarispeed(), source = AVAudioMixerNode()
                engine.attach(player); engine.attach(rate); engine.attach(source)
                engine.connect(player, to: rate, format: mono)
                engine.connect(rate, to: source, format: mono)
                engine.connect(source, to: space, format: mono)
                source.sourceMode = .spatializeIfMono
                #if targetEnvironment(simulator)
                source.renderingAlgorithm = .sphericalHead
                #else
                source.renderingAlgorithm = .HRTF
                #endif
                source.reverbBlend = 0.2
                players.append(player); rates.append(rate); sources.append(source)
            }
            let probe = meter
            engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in probe.consume(buffer) }
            engine.mainMixerNode.outputVolume = volume * 0.75
            engine.prepare(); try engine.start()
            ready = true; status = "Spatial acoustic engine ready"
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                    let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if raw == AVAudioSession.InterruptionType.began.rawValue {
                            self.engine.pause(); self.ready = false; self.status = "Audio interrupted"
                        } else { self.resume() }
                    }
                }
        } catch { status = "Audio unavailable: \(error.localizedDescription)"; ready = false }
    }

    func play(string: Int, strength: Float, tension: Float, position: V3, soft: Bool = false, soundscape: Soundscape = .nocturne) {
        guard ready, buffers.indices.contains(string) else { return }
        let i = cursor % players.count; cursor += 1
        let player = players[i], rate = rates[i], source = sources[i]
        player.stop()
        rate.rate = soundscape.rate(string) * pow(2, min(0.18, max(0, tension)) * 3.5)
        source.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        source.volume = (soft ? 0.07 : 0.19) * min(1, max(0.05, strength))
        player.scheduleBuffer(buffers[string], at: nil)
        player.play()
    }
    func listener(transform: simd_float4x4) {
        let p = transform.columns.3
        space.listenerPosition = AVAudio3DPoint(x: p.x, y: p.y, z: p.z)
        let f = -transform.columns.2, up = transform.columns.1
        space.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: f.x, y: f.y, z: f.z),
            up: AVAudio3DVector(x: up.x, y: up.y, z: up.z))
    }
    func resume() {
        guard !buffers.isEmpty else { return }
        if engine.isRunning { ready = true; return }
        activationTask?.cancel()
        activationTask = Task {
            do {
                let session = AVAudioSession.sharedInstance()
                if #available(visionOS 27.0, *) { _ = try await session.activate(options: []) }
                else { try await Task.detached { try session.setActive(true) }.value }
                guard !Task.isCancelled else { return }
                try engine.start(); ready = true; status = "Spatial acoustic engine ready"
            } catch { ready = false; status = "Audio paused: \(error.localizedDescription)" }
        }
    }
    func silence() { players.forEach { $0.stop() } }
    func suspend() { activationTask?.cancel(); activationTask = nil; silence(); engine.pause(); ready = false }
}
