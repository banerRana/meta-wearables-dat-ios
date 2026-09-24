/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if DEBUG

import Foundation
import MWDATCore
import MWDATInputs
import MWDATMockDevice
import Observation
import os.log

@Observable
@MainActor
final class DebugMenuViewModel {
  var showDebugMenu: Bool = false
  private(set) var isEnabled: Bool
  private(set) var isPoweredOn: Bool = false
  private(set) var errorMessage: String?

  @ObservationIgnored private let mockDeviceKit: MockDeviceKitInterface
  @ObservationIgnored private var glasses: MockGlasses?
  @ObservationIgnored private let logger = Logger(
    subsystem: "com.meta.wearables.external.SensorsSample",
    category: "MockDeviceKit"
  )

  init(mockDeviceKit: MockDeviceKitInterface) {
    self.mockDeviceKit = mockDeviceKit
    self.isEnabled = mockDeviceKit.isEnabled
  }

  func openFromFab() {
    if !isEnabled {
      enable()
    }
    showDebugMenu = true
  }

  func dismiss() {
    showDebugMenu = false
    disable()
  }

  func enable() {
    mockDeviceKit.enable()
    isEnabled = true
  }

  func disable() {
    mockDeviceKit.disable()
    glasses = nil
    isPoweredOn = false
    isEnabled = false
  }

  private func pairGlassesIfNeeded() -> MockGlasses? {
    if let glasses {
      return glasses
    }

    let device: MockGlasses
    do {
      device = try mockDeviceKit.pairGlasses(model: .rayBanMeta)
    } catch {
      logger.error("Failed to pair mock glasses: \(error.localizedDescription, privacy: .public)")
      errorMessage = "Failed to pair mock glasses: \(error.localizedDescription)"
      return nil
    }
    errorMessage = nil
    glasses = device
    return device
  }

  // MARK: - Power

  func powerOnAndWear() {
    guard let glasses = pairGlassesIfNeeded() else { return }
    glasses.services.speech.setTranscriptionSource(.liveDeviceAsr)
    glasses.powerOn()
    glasses.unfold()
    glasses.don()
    isPoweredOn = true
  }

  func powerOff() {
    glasses?.powerOff()
    disable()
  }

  // MARK: - Input injection

  func navUp() { glasses?.services.input.navUp() }
  func navDown() { glasses?.services.input.navDown() }
  func navLeft() { glasses?.services.input.navLeft() }
  func navRight() { glasses?.services.input.navRight() }
  func select() { glasses?.services.input.select() }
  func back() { glasses?.services.input.back() }
  func action() { glasses?.services.input.button(type: .action) }
  func capture() { glasses?.services.input.capture(pressType: .shortPress) }
  func hold() { glasses?.services.input.capture(pressType: .hold) }
  func doubleCapture() { glasses?.services.input.capture(pressType: .doublePress) }

  func drag() {
    guard let input = glasses?.services.input else { return }
    input.drag(action: .down, x: 0.25, y: 0.5, dx: 0, dy: 0)
    input.drag(action: .move, x: 0.75, y: 0.5, dx: 0.5, dy: 0)
    input.drag(action: .up, x: 0.75, y: 0.5, dx: 0, dy: 0)
  }
}

#endif
