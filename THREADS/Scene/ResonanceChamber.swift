import RealityKit
import UIKit
import simd

@MainActor
final class ResonanceChamber {
    let root = Entity()
    let instrument = Entity()
    private(set) var strings: [[ModelEntity]] = []
    private var contacts: [ModelEntity] = []
    private var pulses: [ModelEntity] = []
    private var sculptures: [Entity] = []
    private var sculpturePulses: [ModelEntity] = []
    private let unitLine = MeshResource.generateCylinder(height: 1, radius: 1)
    private let sphere = MeshResource.generateSphere(radius: 1)
    private var lineMaterial = UnlitMaterial(color: UIColor(red: 0.47, green: 0.78, blue: 1, alpha: 1))
    private var iceMaterial = UnlitMaterial(color: UIColor(red: 0.74, green: 0.96, blue: 1, alpha: 1))
    private var calibrated = false
    var isCalibrated: Bool { calibrated }
    private var headTransform: simd_float4x4?
    var reach = PlayingReach.relaxed {
        didSet { if let headTransform { calibrate(to: headTransform, force: true) } }
    }
    private(set) var decorativeCount = 0
    private(set) var triangleCount = 0
    var reducedMotion = false

    func build() throws {
        root.name = "THREADS • Resonance Chamber"
        root.addChild(instrument)
        instrument.name = "Seated instrument"
        instrument.position = [0, 1.65, 0]
        root.components.set(OpacityComponent(opacity: 0))
        try buildArchitecture()
        let placements: [(V3, Float, Float)] = [
            ([-3.2, 0, -3.5], 1.18, 0.5), ([3.3, 0, -4.0], 1.35, -0.7),
            ([0.1, 0, -7.2], 1.65, 1.1), ([-4.6, 0, 2.4], 1.25, -1.3),
            ([4.7, 0, 2.8], 1.45, 0.8)
        ]
        for (i, value) in placements.enumerated() {
            try buildSculpture(center: value.0, radius: value.1, twist: value.2, index: i)
        }
        try buildCanopy()
        try buildInstrument()
    }

    private func model(_ mesh: MeshResource, _ material: any Material, position: V3 = .zero) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material]); entity.position = position; return entity
    }
    private func ring(parent: Entity, center: V3, radius: Float, thickness: Float, color: UIColor) throws {
        var geometry = TubeMesh(); geometry.add(path: TubeMesh.ring(center: center, radius: radius), radius: thickness, sides: 6)
        parent.addChild(model(try geometry.resource(name: "Lathed light ring"), UnlitMaterial(color: color)))
    }
    private func buildArchitecture() throws {
        let dark = SimpleMaterial(color: UIColor(red: 0.022, green: 0.033, blue: 0.065, alpha: 1), roughness: 0.38, isMetallic: true)
        root.addChild(model(.generateCylinder(height: 0.12, radius: 16), UnlitMaterial(color: UIColor(red: 0.009, green: 0.016, blue: 0.028, alpha: 1)), position: [0, -0.08, 0]))
        root.addChild(model(.generateCylinder(height: 0.13, radius: 15.5), UnlitMaterial(color: UIColor(red: 0.006, green: 0.010, blue: 0.022, alpha: 1)), position: [0, 6.2, 0]))
        for i in 0..<24 {
            let angle = Float(i) * .pi * 2 / 24
            let panel = model(.generateBox(width: 2.8, height: 6.2, depth: 0.12), dark,
                              position: [sin(angle) * 15, 3.05, cos(angle) * 15])
            panel.orientation = simd_quatf(angle: angle, axis: [0, 1, 0]); root.addChild(panel)
            let rib = model(.generateBox(width: 0.045, height: 0.09, depth: 15), dark,
                            position: [sin(angle) * 7.4, 6.04, cos(angle) * 7.4])
            rib.orientation = simd_quatf(angle: angle, axis: [0, 1, 0]); root.addChild(rib)
            if i % 3 == 0 {
                let marker = model(.generateBox(width: 0.025, height: 0.48, depth: 0.025),
                                   UnlitMaterial(color: UIColor(red: 0.11, green: 0.17, blue: 0.22, alpha: 1)),
                                   position: [sin(angle) * 14.9, 1.4, cos(angle) * 14.9])
                root.addChild(marker)
            }
        }
        let distant = UIColor(red: 0.025, green: 0.075, blue: 0.14, alpha: 1)
        for radius: Float in [3, 6, 10, 14] {
            try ring(parent: root, center: [0, 0.002, 0], radius: radius, thickness: 0.005, color: distant)
            try ring(parent: root, center: [0, 6.0, 0], radius: radius, thickness: 0.012, color: distant)
        }
        let key = DirectionalLight(); key.light.color = UIColor(red: 0.32, green: 0.55, blue: 0.9, alpha: 1)
        key.light.intensity = 650; key.look(at: [0, 0, -2], from: [2, 6, 1], relativeTo: nil); root.addChild(key)
        for position: V3 in [[-3, 1.0, -3], [3, 1.0, -4], [0, 1.0, -7]] {
            let light = PointLight(); light.position = position
            light.light.color = UIColor(red: 0.17, green: 0.48, blue: 1, alpha: 1)
            light.light.intensity = 180; light.light.attenuationRadius = 4; root.addChild(light)
        }
    }
    private func buildSculpture(center: V3, radius: Float, twist: Float, index: Int) throws {
        let group = Entity(); group.position = center; root.addChild(group); sculptures.append(group)
        let plinth = SimpleMaterial(color: UIColor(red: 0.025, green: 0.05, blue: 0.09, alpha: 1), roughness: 0.26, isMetallic: true)
        group.addChild(model(.generateCylinder(height: 0.36, radius: radius), plinth, position: [0, 0.18, 0]))
        let discMaterial = UnlitMaterial(color: UIColor(red: 0.055, green: 0.22, blue: 0.36, alpha: 1))
        group.addChild(model(.generateCylinder(height: 0.008, radius: radius * 0.94), discMaterial, position: [0, 0.365, 0]))
        group.addChild(model(.generateCylinder(height: 0.009, radius: radius * 0.72),
                            UnlitMaterial(color: UIColor(red: 0.08, green: 0.29, blue: 0.43, alpha: 1)), position: [0, 0.37, 0]))
        try ring(parent: group, center: [0, 0.375, 0], radius: radius, thickness: 0.012, color: .init(red: 0.30, green: 0.68, blue: 1, alpha: 1))
        for j in 0..<3 {
            let f = Float(j)
            group.addChild(model(.generateCylinder(height: 0.001, radius: radius * (1.5 - f * 0.12)),
                                UnlitMaterial(color: UIColor(red: CGFloat(0.009 + f * 0.002), green: CGFloat(0.025 + f * 0.008), blue: CGFloat(0.047 + f * 0.012), alpha: 1)),
                                position: [0, 0.001 + f * 0.0015, 0]))
        }
        try ring(parent: group, center: [0, 0.38, 0], radius: radius * 0.84, thickness: 0.004, color: .init(red: 0.06, green: 0.25, blue: 0.42, alpha: 1))
        try ring(parent: group, center: [0, 5.4, 0], radius: radius * 1.10, thickness: 0.018, color: .init(red: 0.04, green: 0.10, blue: 0.17, alpha: 1))
        var blue = TubeMesh(), pale = TubeMesh()
        let strands = 88
        for j in 0..<strands {
            let angle = Float(j) / Float(strands) * .pi * 2
            let start = V3(cos(angle) * radius * 0.94, 0.38, sin(angle) * radius * 0.94)
            let topAngle = angle + twist + .pi * 0.74
            let end = V3(cos(topAngle) * radius * 1.08, 5.4, sin(topAngle) * radius * 1.08)
            let path: [V3] = (0...18).map { k in
                let t = Float(k) / 18
                let bow = sin(t * .pi) * 0.26
                return start + (end - start) * t + V3(sin(angle + t * 2) * bow, 0, cos(angle + t * 2) * bow)
            }
            if j % 4 == 0 { pale.add(path: path, radius: 0.0033) }
            else { blue.add(path: path, radius: 0.0025) }
        }
        // Each complete lattice is two shared mesh draws, rather than hundreds of cylinder entities.
        triangleCount += (blue.indices.count + pale.indices.count) / 3
        decorativeCount += strands
        group.addChild(model(try blue.resource(name: "Twisted architectural lattice"),
                             UnlitMaterial(color: UIColor(red: 0.11, green: 0.40, blue: 0.72, alpha: 1))))
        group.addChild(model(try pale.resource(name: "Ice filaments"),
                             UnlitMaterial(color: UIColor(red: 0.40, green: 0.69, blue: 0.88, alpha: 1))))
        let pulse = model(sphere, iceMaterial); pulse.scale = [0.018, 0.018, 0.018]
        group.addChild(pulse); sculpturePulses.append(pulse)
    }
    private func buildCanopy() throws {
        var web = TubeMesh()
        // Ruled ribbons frame the room overhead and cross behind the seated playing region.
        for side: Float in [-1, 1] {
            for j in 0..<40 {
                let u = Float(j) / 39
                let a = V3(side * (2.1 + u * 2.3), 0.4, 1.3 + u * 1.7)
                let b = V3(side * (-1.2 + u * 1.2), 5.85, -5.2 - u * 3.4)
                let path = (0...20).map { k -> V3 in
                    let t = Float(k) / 20
                    return a + (b - a) * t + V3(side * sin(t * .pi) * 1.8, sin(t * .pi) * 0.6, 0)
                }
                web.add(path: path, radius: 0.0020)
            }
        }
        decorativeCount += 80; triangleCount += web.indices.count / 3
        root.addChild(model(try web.resource(name: "Sweeping ceiling ribbons"),
                            UnlitMaterial(color: UIColor(red: 0.07, green: 0.24, blue: 0.44, alpha: 1))))
    }
    private func buildInstrument() throws {
        let foot = model(.generateBox(width: 1.23, height: 0.035, depth: 0.14, cornerRadius: 0.04),
                         SimpleMaterial(color: UIColor(red: 0.035, green: 0.06, blue: 0.10, alpha: 1), roughness: 0.3, isMetallic: true),
                         position: [0, -0.72, -0.56]); instrument.addChild(foot)
        try ring(parent: instrument, center: [0, -0.75, -0.65], radius: 0.78, thickness: 0.005,
                 color: UIColor(red: 0.08, green: 0.28, blue: 0.44, alpha: 1))
        for i in 0..<Instrument.count {
            var segments: [ModelEntity] = []
            for _ in 0..<14 {
                let segment = model(unitLine, lineMaterial); instrument.addChild(segment); segments.append(segment)
            }
            strings.append(segments)
            let contact = model(sphere, iceMaterial, position: Instrument.center(i))
            contact.name = "string-\(i)"; contact.scale = [0.008, 0.008, 0.008]
            contact.components.set(CollisionComponent(shapes: [.generateSphere(radius: 3.8)]))
            contact.components.set(InputTargetComponent())
            contact.components.set(HoverEffectComponent())
            instrument.addChild(contact); contacts.append(contact)
            let pulse = model(sphere, iceMaterial); pulse.scale = [0.006, 0.018, 0.006]
            pulse.isEnabled = false; instrument.addChild(pulse); pulses.append(pulse)
        }
    }
    func calibrate(to head: simd_float4x4, force: Bool = false) {
        guard !calibrated || force else { return }
        headTransform = head
        let p = head.columns.3, forward = -head.columns.2
        let yaw = atan2(-forward.x, -forward.z)
        let rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        instrument.position = V3(p.x, p.y, p.z) + rotation.act(reach.offset)
        instrument.orientation = rotation; calibrated = true
    }
    func prepareEntry() { calibrated = false }
    func localPoint(_ world: V3) -> V3 { instrument.convert(position: world, from: nil) }
    func worldPoint(_ local: V3) -> V3 { instrument.convert(position: local, to: nil) }
    func animate(motions: [StringMotion], time: Float, fade: Float, resonance: Float, guidedTarget: Int? = nil) {
        root.components.set(OpacityComponent(opacity: fade))
        for i in 0..<strings.count {
            let motion = motions[i], (a, b) = Instrument.endpoints(i)
            for j in 0..<14 {
                let start = motion.point(a, b, t: Float(j) / 14), end = motion.point(a, b, t: Float(j + 1) / 14)
                let delta = end - start
                let entity = strings[i][j]
                entity.position = (start + end) * 0.5
                let radius: Float = 0.0016 + motion.energy * 0.0011 + motion.proximity * 0.0006 + (guidedTarget == i ? 0.001 : 0)
                entity.scale = [radius, simd_length(delta), radius]
                entity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
            }
            let center = motion.point(a, b, t: 0.47)
            contacts[i].position = center
            let size: Float = (guidedTarget == i ? 0.014 : 0.009) + motion.proximity * 0.004 + motion.energy * 0.003
            contacts[i].scale = V3(repeating: size)
            pulses[i].isEnabled = motion.pulse < 1
            if motion.pulse < 1 { pulses[i].position = motion.point(a, b, t: motion.pulse) }
        }
        for i in sculpturePulses.indices {
            let t = (time * (reducedMotion ? 0.025 : 0.075) + Float(i) * 0.21).truncatingRemainder(dividingBy: 1)
            sculpturePulses[i].position = [cos(t * 6.28 + Float(i)) * 0.8, 0.40 + t * 5, sin(t * 6.28 + Float(i)) * 0.8]
            let breath = 0.70 + 0.10 * sin(time * 0.32 + Float(i)) + resonance * 0.18
            sculptures[i].components.set(OpacityComponent(opacity: breath))
        }
    }
}
