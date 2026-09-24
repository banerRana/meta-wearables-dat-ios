/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATMotion
import SwiftUI

/// Visualizes the live Motion stream: a wireframe pair of glasses that rotates with the device.
///
/// The wireframe is driven by the fused ``MotionSample/orientation`` quaternion when present;
/// otherwise it derives pitch/roll from the accelerometer's gravity vector so it still responds to
/// head movement.
struct WireframeGlassesView: View {
  let sample: MotionSample?

  var body: some View {
    Canvas { context, size in
      let q = Self.rotationQuaternion(from: sample)
      let cx = size.width / 2
      let cy = size.height / 2
      let scale = min(size.width, size.height) / 5

      let projected = Self.vertices.map { vertex -> CGPoint in
        let r = Self.rotate(vertex, q)
        return CGPoint(x: cx + r.x * scale, y: cy - r.y * scale)
      }

      for edge in Self.edges {
        var path = Path()
        path.move(to: projected[edge.0])
        path.addLine(to: projected[edge.1])
        context.stroke(
          path,
          with: .color(AppColor.wireframe),
          style: StrokeStyle(lineWidth: 5)
        )
      }
    }
  }

  private struct Vertex {
    let x: Double
    let y: Double
    let z: Double
  }

  private static let vertices: [Vertex] = {
    func rect(_ cx: Double) -> [Vertex] {
      [
        Vertex(x: cx - 0.45, y: 0.30, z: 0),
        Vertex(x: cx + 0.45, y: 0.30, z: 0),
        Vertex(x: cx + 0.45, y: -0.30, z: 0),
        Vertex(x: cx - 0.45, y: -0.30, z: 0),
      ]
    }
    var all = rect(-0.55) + rect(0.55)
    all.append(Vertex(x: -1.0, y: 0.30, z: 0))
    all.append(Vertex(x: -1.9, y: 0.55, z: -0.9))
    all.append(Vertex(x: 1.0, y: 0.30, z: 0))
    all.append(Vertex(x: 1.9, y: 0.55, z: -0.9))
    return all
  }()

  private static let edges: [(Int, Int)] = [
    (0, 1), (1, 2), (2, 3), (3, 0),
    (4, 5), (5, 6), (6, 7), (7, 4),
    (1, 4),
    (8, 9),
    (10, 11),
  ]

  private static func rotationQuaternion(from sample: MotionSample?) -> (x: Double, y: Double, z: Double, w: Double) {
    guard let sample else { return (0, 0, 0, 1) }
    if let q = sample.orientation {
      return (Double(q.x), Double(q.y), Double(q.z), Double(q.w))
    }
    guard let accelerometer = sample.accelerometer else { return (0, 0, 0, 1) }
    return quaternionFromAccelerometer(accelerometer)
  }

  private static func quaternionFromAccelerometer(_ accelerometer: Vector3) -> (x: Double, y: Double, z: Double, w: Double) {
    let ax = Double(accelerometer.x)
    let ay = Double(accelerometer.y)
    let az = Double(accelerometer.z)
    let roll = atan2(ay, az)
    let pitch = atan2(-ax, (ay * ay + az * az).squareRoot())

    let cr = cos(roll / 2)
    let sr = sin(roll / 2)
    let cp = cos(pitch / 2)
    let sp = sin(pitch / 2)

    return (sr * cp, cr * sp, -sp * sr, cr * cp)
  }

  private static func rotate(_ v: Vertex, _ q: (x: Double, y: Double, z: Double, w: Double)) -> Vertex {
    let norm = (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w).squareRoot()
    if norm < 1e-10 { return v }
    let x = q.x / norm
    let y = q.y / norm
    let z = q.z / norm
    let w = q.w / norm

    let tx = 2 * (y * v.z - z * v.y)
    let ty = 2 * (z * v.x - x * v.z)
    let tz = 2 * (x * v.y - y * v.x)

    return Vertex(
      x: v.x + w * tx + (y * tz - z * ty),
      y: v.y + w * ty + (z * tx - x * tz),
      z: v.z + w * tz + (x * ty - y * tx)
    )
  }
}
