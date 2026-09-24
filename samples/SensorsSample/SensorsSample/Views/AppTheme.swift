/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATMotion
import SwiftUI

enum AppColor {
  static let background = rgb(0x0B, 0x0D, 0x12)
  static let surface = rgb(0x16, 0x1A, 0x22)
  static let surfaceVariant = rgb(0x22, 0x28, 0x34)
  static let onSurface = rgb(0xE6, 0xEA, 0xF2)
  static let onSurfaceMuted = rgb(0x8A, 0x93, 0xA6)

  static let motion = rgb(0x3D, 0xD7, 0xC4)
  static let inputs = rgb(0xFF, 0xB8, 0x4D)
  static let speech = rgb(0x7C, 0x9C, 0xFF)

  static let wireframe = rgb(0x5E, 0xE1, 0xFF)
  static let accent = rgb(0x00, 0x64, 0xE0)
  static let positive = rgb(0x61, 0xBC, 0x63)
  static let warning = rgb(0xFF, 0xCC, 0x00)
  static let error = rgb(0xFF, 0x45, 0x3A)
  static let shutter = Color.white

  private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
    Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
  }
}

struct StatusRow: View {
  let motionState: String
  let motionError: String?
  let inputsState: String
  let inputsError: String?
  let speechState: String
  let speechError: String?

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      StatusChip(label: "Motion", state: motionState, accent: AppColor.motion, errorText: motionError)
      StatusChip(label: "Inputs", state: inputsState, accent: AppColor.inputs, errorText: inputsError)
      StatusChip(label: "Speech", state: speechState, accent: AppColor.speech, errorText: speechError)
    }
    .padding(.horizontal, 16)
  }
}

struct StatusChip: View {
  let label: String
  let state: String
  let accent: Color
  let errorText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        Circle()
          .fill(accent)
          .frame(width: 8, height: 8)
        Text(label)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppColor.onSurface)
      }
      Text(state)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(AppColor.onSurfaceMuted)
      if let errorText {
        Text(errorText)
          .font(.system(size: 10))
          .foregroundStyle(AppColor.error)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(AppColor.surface.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

struct MotionReadout: View {
  let sample: MotionSample?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      AxisRow(label: "Accel", unit: "m/s²", vector: sample?.accelerometer)
      AxisRow(label: "Gyro", unit: "rad/s", vector: sample?.gyroscope)
      Text(orientationStatus)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(AppColor.onSurfaceMuted)
        .accessibilityIdentifier("orientation_status")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(AppColor.surface.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 16)
  }

  private var orientationStatus: String {
    guard let sample else { return "Orientation: —" }
    return sample.orientation != nil ? "Orientation: fused" : "Orientation: from accelerometer"
  }
}

struct AxisRow: View {
  let label: String
  let unit: String
  let vector: Vector3?

  var body: some View {
    HStack(spacing: 8) {
      HStack(spacing: 6) {
        Circle()
          .fill(AppColor.motion)
          .frame(width: 8, height: 8)
        Text(label)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppColor.onSurface)
      }
      .frame(width: 74, alignment: .leading)
      component("X", vector?.x)
      component("Y", vector?.y)
      component("Z", vector?.z)
      Text(unit)
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(AppColor.onSurfaceMuted)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private func component(_ axis: String, _ value: Float?) -> some View {
    HStack(spacing: 3) {
      Text(axis)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(AppColor.onSurfaceMuted)
      Text(value.map { String(format: "%+.2f", $0) } ?? "  —  ")
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(AppColor.onSurface)
    }
    .frame(width: 68, alignment: .leading)
  }
}

struct ConnectionRow: View {
  let registrationState: String
  let sessionState: String
  let canRegister: Bool
  let onRegister: () -> Void
  let canDisconnect: Bool
  let onDisconnect: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Text("Registration: \(registrationState)")
        .font(.system(size: 12))
        .foregroundStyle(AppColor.onSurfaceMuted)
        .padding(.trailing, 12)
      Text("Session: \(sessionState)")
        .font(.system(size: 12))
        .foregroundStyle(AppColor.onSurfaceMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
      if canRegister {
        Button("Register", action: onRegister)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(AppColor.accent)
          .accessibilityIdentifier("register_button")
      }
      if canDisconnect {
        Button("Disconnect", action: onDisconnect)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(AppColor.error)
          .accessibilityIdentifier("disconnect_button")
      }
    }
    .padding(.horizontal, 16)
  }
}

struct ErrorBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(AppColor.error)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button("Dismiss", action: onDismiss)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppColor.error)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(AppColor.error.opacity(0.18))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 16)
  }
}

struct RealDeviceHint: View {
  var body: some View {
    Text("Connect and register your glasses to begin.")
      .font(.system(size: 12))
      .foregroundStyle(AppColor.onSurfaceMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
  }
}

struct InputFlashOverlay: View {
  let control: InputControl?
  let token: UInt64

  @State private var opacity: Double = 0
  @State private var progress: Double = 0

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      ZStack {
        if let control {
          effect(for: control, side: side)
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .allowsHitTesting(false)
    .onChange(of: token) { _, _ in
      opacity = 1
      progress = 0
      withAnimation(.easeOut(duration: 0.75)) {
        opacity = 0
        progress = 1
      }
    }
  }

  @ViewBuilder
  private func effect(for control: InputControl, side: CGFloat) -> some View {
    switch control {
    case .up:
      Image(systemName: "arrow.up")
        .font(.system(size: side / 3, weight: .heavy))
        .foregroundStyle(AppColor.inputs)
        .opacity(opacity)
    case .down:
      Image(systemName: "arrow.down")
        .font(.system(size: side / 3, weight: .heavy))
        .foregroundStyle(AppColor.inputs)
        .opacity(opacity)
    case .left:
      Image(systemName: "arrow.left")
        .font(.system(size: side / 3, weight: .heavy))
        .foregroundStyle(AppColor.inputs)
        .opacity(opacity)
    case .right:
      Image(systemName: "arrow.right")
        .font(.system(size: side / 3, weight: .heavy))
        .foregroundStyle(AppColor.inputs)
        .opacity(opacity)
    case .select:
      Circle()
        .stroke(AppColor.inputs, lineWidth: 8)
        .frame(width: side * (0.25 + progress * 0.65), height: side * (0.25 + progress * 0.65))
        .opacity(opacity)
    case .capture:
      Rectangle()
        .fill(AppColor.shutter)
        .opacity(opacity * 0.55)
    case .back:
      Text("\u{21A9}")
        .font(.system(size: side / 3))
        .foregroundStyle(AppColor.inputs)
        .opacity(opacity)
    case .button:
      RoundedRectangle(cornerRadius: 6)
        .fill(AppColor.inputs)
        .frame(width: side / 6, height: side / 3)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .opacity(opacity * 0.8)
    case .drag:
      HStack(spacing: 0) {
        Capsule()
          .fill(AppColor.speech)
          .frame(width: side / 2, height: 10)
        Circle()
          .fill(AppColor.speech)
          .frame(width: 22, height: 22)
      }
      .opacity(opacity)
    }
  }
}
