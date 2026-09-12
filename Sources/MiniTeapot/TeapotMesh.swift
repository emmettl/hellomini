import Foundation
import simd

struct TeapotVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
}

struct TeapotMesh {
  let vertices: [TeapotVertex]
  let indices: [UInt32]

  private struct ControlNet: Decodable {
    let patches: [[Int]]
    let points: [[Float]]
  }

  static func make(subdivisions: Int = 16) throws -> Self {
    precondition((2...64).contains(subdivisions))
    guard
      let url = Bundle.teapotResources.url(
        forResource: "Teapot", withExtension: "json", subdirectory: "Resources")
    else {
      throw TeapotError.unavailable("The teapot model is missing.")
    }
    let net = try JSONDecoder().decode(ControlNet.self, from: Data(contentsOf: url))
    guard net.patches.count == 10,
      net.points.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
      net.patches.allSatisfy({ $0.count == 16 && $0.allSatisfy { net.points.indices.contains($0) } }
      )
    else {
      throw TeapotError.unavailable("The teapot model is invalid.")
    }
    var vertices: [TeapotVertex] = []
    var indices: [UInt32] = []
    for (patchIndex, patch) in net.patches.enumerated() {
      let points = patch.map {
        SIMD3<Float>(net.points[$0][0], net.points[$0][1], net.points[$0][2])
      }
      // Body, lid and bottom cover four quadrants; handle and spout have two mirrored halves.
      for copy in 0..<(patchIndex < 6 ? 4 : 2) {
        let base = UInt32(vertices.count)
        func transform(_ p: SIMD3<Float>, position: Bool) -> SIMD4<Float> {
          var p = p
          if patchIndex < 6 {
            let angle = Float(copy) * .pi / 2
            p = SIMD3(cos(angle) * p.x - sin(angle) * p.y, sin(angle) * p.x + cos(angle) * p.y, p.z)
          } else if copy == 1 {
            p.y = -p.y
          }
          return SIMD4(p.x, p.z - (position ? 1.575 : 0), -p.y, position ? 1 : 0)
        }
        for row in 0...subdivisions {
          for column in 0...subdivisions {
            let u = Float(row) / Float(subdivisions)
            let v = Float(column) / Float(subdivisions)
            let position = evaluate(points, u: u, v: v).position
            // Evaluate normals just inside the patch at collapsed lid/bottom poles.
            let sample = evaluate(
              points, u: min(0.9999, max(0.0001, u)), v: min(0.9999, max(0.0001, v)))
            let cross = simd_cross(sample.dv, sample.du)
            let normal =
              simd_length_squared(cross) > 1e-16
              ? simd_normalize(cross) : SIMD3<Float>(0, 0, position.z > 1.5 ? 1 : -1)
            vertices.append(
              TeapotVertex(
                position: transform(position, position: true),
                normal: transform(normal, position: false)))
          }
        }
        for row in 0..<subdivisions {
          for column in 0..<subdivisions {
            let a = base + UInt32(row * (subdivisions + 1) + column)
            let b = a + UInt32(subdivisions + 1)
            indices += [a, b, a + 1, a + 1, b, b + 1]
          }
        }
      }
    }
    return Self(vertices: vertices, indices: indices)
  }

  private static func evaluate(_ points: [SIMD3<Float>], u: Float, v: Float) -> (
    position: SIMD3<Float>, du: SIMD3<Float>, dv: SIMD3<Float>
  ) {
    func basis(_ t: Float) -> ([Float], [Float]) {
      let s = 1 - t
      return (
        [s * s * s, 3 * t * s * s, 3 * t * t * s, t * t * t],
        [-3 * s * s, 3 * s * s - 6 * t * s, 6 * t * s - 3 * t * t, 3 * t * t]
      )
    }
    let (bu, du) = basis(u)
    let (bv, dv) = basis(v)
    var p = SIMD3<Float>.zero
    var pu = SIMD3<Float>.zero
    var pv = SIMD3<Float>.zero
    for i in 0..<4 {
      for j in 0..<4 {
        let point = points[i * 4 + j]
        p += point * bu[i] * bv[j]
        pu += point * du[i] * bv[j]
        pv += point * bu[i] * dv[j]
      }
    }
    return (p, pu, pv)
  }
}

enum TeapotError: LocalizedError {
  case unavailable(String)
  var errorDescription: String? {
    if case .unavailable(let message) = self { message } else { nil }
  }
}
