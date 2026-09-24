/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if DEBUG

import SwiftUI

struct MockDeviceKitSheet: View {
  @Bindable var viewModel: DebugMenuViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        sectionTitle("Mock controls")

        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("mock_error_message")
        }

        if !viewModel.isEnabled {
          filledButton("Enable MockDeviceKit", fullWidth: true, id: "mock_enable_button") {
            viewModel.enable()
          }
        } else {
          deviceRow
          if viewModel.isPoweredOn {
            inputsSection
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(AppColor.surface)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
  }

  // MARK: - Device

  private var deviceRow: some View {
    HStack(spacing: 8) {
      Text("Ray-Ban Meta (Mock)")
        .font(.system(size: 16))
        .foregroundStyle(AppColor.onSurface)
        .frame(maxWidth: .infinity, alignment: .leading)
      if viewModel.isPoweredOn {
        outlinedButton("Power off", id: "mock_power_off_button") { viewModel.powerOff() }
      } else {
        filledButton("Power on & wear", id: "mock_power_on_button") { viewModel.powerOnAndWear() }
      }
    }
  }

  // MARK: - Inputs

  private var inputsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Inject inputs")
      Text("When the mock glasses are powered on and worn, motion follows this device and speech uses this device's microphone automatically.")
        .font(.system(size: 14))
        .foregroundStyle(AppColor.onSurfaceMuted)
        .accessibilityIdentifier("mock_live_device_label")

      VStack(spacing: 8) {
        outlinedButton("Up", id: "input_nav_up_button") { viewModel.navUp() }
        HStack(spacing: 8) {
          outlinedButton("Left", id: "input_nav_left_button") { viewModel.navLeft() }
          filledButton("Select", id: "input_select_button") { viewModel.select() }
          outlinedButton("Right", id: "input_nav_right_button") { viewModel.navRight() }
        }
        outlinedButton("Down", id: "input_nav_down_button") { viewModel.navDown() }
      }
      .frame(maxWidth: .infinity)

      HStack(spacing: 8) {
        outlinedButton("Back", fullWidth: true, id: "input_back_button") { viewModel.back() }
        outlinedButton("Action", fullWidth: true, id: "input_action_button") { viewModel.action() }
        outlinedButton("Drag", fullWidth: true, id: "input_drag_button") { viewModel.drag() }
      }

      HStack(spacing: 8) {
        outlinedButton("Capture", fullWidth: true, id: "input_capture_button") { viewModel.capture() }
        outlinedButton("Hold", fullWidth: true, id: "input_hold_button") { viewModel.hold() }
        outlinedButton("Double", fullWidth: true, id: "input_double_button") { viewModel.doubleCapture() }
      }
    }
  }

  // MARK: - Building blocks

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(AppColor.onSurface)
      .padding(.top, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func filledButton(
    _ title: String,
    fullWidth: Bool = false,
    id: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppColor.accent)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(id)
  }

  private func outlinedButton(
    _ title: String,
    fullWidth: Bool = false,
    id: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppColor.accent)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(
          Capsule().stroke(AppColor.onSurfaceMuted.opacity(0.4), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(id)
  }
}

#endif
