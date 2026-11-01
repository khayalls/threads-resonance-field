import ARKit
import QuartzCore
import simd

struct HandSample {
    var side: Int
    var tip: V3
    var thumb: V3
    var palm: V3
    var open: Bool
    var timestamp: Double
    var pinchAvailable = true

    /// A hidden ring finger must not silence a visible index finger.
    static func make(side: Int, tip: V3?, thumb: V3?, palm: V3?, wrist: V3?,
                     middle: V3?, ring: V3?, timestamp: Double) -> HandSample? {
        guard let tip, tip.x.isFinite, tip.y.isFinite, tip.z.isFinite else { return nil }
        let center = palm ?? wrist ?? tip
        var extended = 0
        if let wrist, let palm {
            let span = max(0.025, simd_distance(palm, wrist))
            for finger in [Optional(tip), middle, ring].compactMap({ $0 }) {
                if simd_distance(finger, wrist) > span * 1.35 { extended += 1 }
            }
        }
        let spread = thumb.map { simd_distance(tip, $0) > 0.028 } ?? true
        return HandSample(side: side, tip: tip, thumb: thumb ?? tip, palm: center,
                          open: extended >= 2 && spread, timestamp: timestamp, pinchAvailable: thumb != nil)
    }
}

@MainActor
final class HandTracking {
    private var session: ARKitSession?
    private var world: WorldTrackingProvider?
    private var tasks: [Task<Void, Never>] = []
    private var generation = 0
    private(set) var active = false
    var onHand: ((Int, HandSample?) -> Void)?
    var onStatus: ((String) -> Void)?

    func start() async {
        stop()
        #if targetEnvironment(simulator)
        onStatus?("Simulator · use the demo keys or pinch a light bead")
        return
        #else
        guard HandTrackingProvider.isSupported else { onStatus?("Hand tracking unavailable · use gaze and pinch"); return }
        // A stopped data provider cannot be reused for a new immersive visit.
        let session = ARKitSession(), hands = HandTrackingProvider(), world = WorldTrackingProvider()
        self.session = session; self.world = world
        let expected = generation
        let authorization = await session.requestAuthorization(for: [.handTracking])
        guard !Task.isCancelled, generation == expected else { return }
        guard authorization[.handTracking] == .allowed else {
            try? await session.run([world])
            onStatus?("Hand access is off · use gaze and pinch, or allow Hands in Settings"); return
        }
        do {
            try await session.run([hands, world])
            guard !Task.isCancelled, generation == expected else { session.stop(); return }
            active = true
            onStatus?("Reach forward · brush across a thread")
            tasks.append(Task { [weak self] in
                guard let self else { return }
                for await update in hands.anchorUpdates {
                    guard !Task.isCancelled, self.generation == expected else { return }
                    let anchor = update.anchor
                    let side = anchor.chirality == .left ? 0 : 1
                    if update.event == .removed { self.onHand?(side, nil); continue }
                    guard anchor.isTracked, let skeleton = anchor.handSkeleton else { self.onHand?(side, nil); continue }
                    func point(_ name: HandSkeleton.JointName) -> V3? {
                        guard skeleton.joint(name).isTracked else { return nil }
                        let p = (anchor.originFromAnchorTransform * skeleton.joint(name).anchorFromJointTransform).columns.3
                        return [p.x, p.y, p.z]
                    }
                    self.onHand?(side, HandSample.make(side: side, tip: point(.indexFingerTip), thumb: point(.thumbTip),
                        palm: point(.middleFingerKnuckle), wrist: point(.wrist), middle: point(.middleFingerTip),
                        ring: point(.ringFingerTip), timestamp: CACurrentMediaTime()))
                }
            })
            tasks.append(Task { [weak self] in
                guard let self else { return }
                for await event in session.events {
                    guard !Task.isCancelled, self.generation == expected else { return }
                    switch event {
                    case .authorizationChanged(type: .handTracking, status: let status) where status != .allowed:
                        self.active = false
                        self.onStatus?("Hand access changed · gaze and pinch is available")
                        self.onHand?(0, nil); self.onHand?(1, nil)
                    case .dataProviderStateChanged(_, let state, let error):
                        if error != nil || state == .stopped {
                            self.active = false
                            self.onStatus?("Tracking paused · gaze and pinch is available")
                            self.onHand?(0, nil); self.onHand?(1, nil)
                        }
                    default: break
                    }
                }
            })
        } catch { onStatus?("Tracking unavailable · gaze and pinch is available") }
        #endif
    }
    func deviceTransform() -> simd_float4x4? {
        guard let world, world.state == .running, let anchor = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), anchor.isTracked else { return nil }
        return anchor.originFromAnchorTransform
    }
    func stop() {
        generation += 1; active = false
        tasks.forEach { $0.cancel() }; tasks.removeAll()
        session?.stop(); session = nil; world = nil
        onHand?(0, nil); onHand?(1, nil)
    }
}
