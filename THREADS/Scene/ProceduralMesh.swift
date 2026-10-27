import RealityKit
import simd

struct TubeMesh {
    var positions: [V3] = []
    var normals: [V3] = []
    var indices: [UInt32] = []
    mutating func add(path: [V3], radius: Float, sides: Int = 4) {
        guard path.count > 1 else { return }
        let base = UInt32(positions.count)
        for i in path.indices {
            let tangent = simd_normalize(path[min(i + 1, path.count - 1)] - path[max(0, i - 1)])
            let helper = abs(tangent.y) < 0.95 ? V3(0, 1, 0) : V3(1, 0, 0)
            let u = simd_normalize(simd_cross(tangent, helper)), v = simd_cross(tangent, u)
            for side in 0..<sides {
                let angle = Float(side) * .pi * 2 / Float(sides)
                let n = u * cos(angle) + v * sin(angle)
                positions.append(path[i] + n * radius); normals.append(n)
                if i < path.count - 1 {
                    let a = base + UInt32(i * sides + side)
                    let b = base + UInt32(i * sides + (side + 1) % sides)
                    let c = a + UInt32(sides), d = b + UInt32(sides)
                    indices += [a, b, c, b, d, c]
                }
            }
        }
    }
    @MainActor func resource(name: String) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
    static func ring(center: V3, radius: Float, segments: Int = 96) -> [V3] {
        (0...segments).map { i in
            let angle = Float(i) / Float(segments) * .pi * 2
            return center + V3(cos(angle) * radius, 0, sin(angle) * radius)
        }
    }
}
