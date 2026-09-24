/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if DEBUG

import MWDATMockDevice
import SwiftUI

@MainActor
class DebugMenuViewModel: ObservableObject {
  @Published public var showDebugMenu: Bool = false
  private let mockDeviceKit: MockDeviceKitInterface
  @Published var pairedCount: Int = 0
  @Published var isEnabled: Bool

  init(mockDeviceKit: MockDeviceKitInterface) {
    self.mockDeviceKit = mockDeviceKit
    self.isEnabled = mockDeviceKit.isEnabled
    self.pairedCount = mockDeviceKit.pairedDevices.count
  }

  func enable() {
    mockDeviceKit.enable()
    isEnabled = true
  }

  func disable() {
    mockDeviceKit.disable()
    pairedCount = 0
    isEnabled = false
  }

  func pairGlasses() {
    let device: MockGlasses
    do {
      device = try mockDeviceKit.pairGlasses(model: .rayBanMeta)
    } catch {
      print("Failed to pair mock glasses: \(error)")
      return
    }
    device.powerOn()
    device.don()
    pairedCount = mockDeviceKit.pairedDevices.count
  }

  func unpairLastDevice() {
    if let device = mockDeviceKit.pairedDevices.last {
      mockDeviceKit.unpairDevice(device)
      pairedCount = mockDeviceKit.pairedDevices.count
    }
  }
}

#endif
