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
}

@MainActor
final class HandTracking {
    private let session = ARKitSession()
    private let hands = HandTrackingProvider()
    private let world = WorldTrackingProvider()
    private var tasks: [Task<Void, Never>] = []
    var onHand: ((Int, HandSample?) -> Void)?
    var onStatus: ((String) -> Void)?

    func start() async {
        stop()
        #if targetEnvironment(simulator)
        onStatus?("Simulator · use the demo keys or pinch a light bead")
        return
        #else
        guard HandTrackingProvider.isSupported else { onStatus?("Hand tracking unavailable · use gaze and pinch"); return }
        let authorization = await session.requestAuthorization(for: [.handTracking])
        guard authorization[.handTracking] == .allowed else {
            try? await session.run([world])
            onStatus?("Hand access is off · use gaze and pinch, or allow Hands in Settings"); return
        }
        do {
            try await session.run([hands, world])
            onStatus?("Reach forward · brush across a thread")
            tasks.append(Task { [weak self] in
                guard let self else { return }
                for await update in self.hands.anchorUpdates {
                    guard !Task.isCancelled else { return }
                    let anchor = update.anchor
                    let side = anchor.chirality == .left ? 0 : 1
                    guard anchor.isTracked, let skeleton = anchor.handSkeleton else { self.onHand?(side, nil); continue }
                    let needed: [HandSkeleton.JointName] = [.indexFingerTip, .thumbTip, .middleFingerKnuckle, .wrist, .middleFingerTip, .ringFingerTip]
                    guard needed.allSatisfy({ skeleton.joint($0).isTracked }) else { self.onHand?(side, nil); continue }
                    func point(_ name: HandSkeleton.JointName) -> V3 {
                        let p = (anchor.originFromAnchorTransform * skeleton.joint(name).anchorFromJointTransform).columns.3
                        return [p.x, p.y, p.z]
                    }
                    let wrist = point(.wrist), palm = point(.middleFingerKnuckle)
                    let open = simd_distance(point(.middleFingerTip), wrist) > simd_distance(palm, wrist) * 1.55 &&
                        simd_distance(point(.ringFingerTip), wrist) > simd_distance(palm, wrist) * 1.45 &&
                        simd_distance(point(.indexFingerTip), point(.thumbTip)) > 0.045
                    self.onHand?(side, HandSample(side: side, tip: point(.indexFingerTip), thumb: point(.thumbTip),
                                                 palm: palm, open: open, timestamp: CACurrentMediaTime()))
                }
            })
            tasks.append(Task { [weak self] in
                guard let self else { return }
                for await event in self.session.events {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .authorizationChanged(type: .handTracking, status: let status) where status != .allowed:
                        self.onStatus?("Hand access changed · gaze and pinch is available")
                        self.onHand?(0, nil); self.onHand?(1, nil)
                    case .dataProviderStateChanged(_, let state, let error):
                        if error != nil || state == .stopped {
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
        guard world.state == .running, let anchor = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), anchor.isTracked else { return nil }
        return anchor.originFromAnchorTransform
    }
    func stop() { tasks.forEach { $0.cancel() }; tasks.removeAll(); session.stop(); onHand?(0, nil); onHand?(1, nil) }
}
