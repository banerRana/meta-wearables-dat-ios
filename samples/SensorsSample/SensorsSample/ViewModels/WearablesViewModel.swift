/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATCore
import Observation
import SwiftUI

@Observable
@MainActor
final class WearablesViewModel {
  var devices: [DeviceIdentifier]
  var registrationState: RegistrationState
  var showError: Bool = false
  var errorMessage: String = ""

  var hasCompletedRegistration: Bool {
    registrationState == .registered
  }

  var isRegistrationBusy: Bool {
    registrationState == .registering
  }

  var canRegister: Bool {
    !hasCompletedRegistration && !isRegistrationBusy
  }

  var canDisconnect: Bool {
    registrationState == .registered
  }

  @ObservationIgnored private var registrationTask: Task<Void, Never>?
  @ObservationIgnored private var deviceStreamTask: Task<Void, Never>?
  @ObservationIgnored private let wearables: WearablesInterface

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    self.devices = wearables.devices
    self.registrationState = wearables.registrationState

    deviceStreamTask = Task { [weak self] in
      guard let self else { return }
      for await devices in self.wearables.devicesStream() {
        self.devices = devices
      }
    }

    registrationTask = Task { [weak self] in
      guard let self else { return }
      for await registrationState in self.wearables.registrationStateStream() {
        self.registrationState = registrationState
      }
    }
  }

  isolated deinit {
    registrationTask?.cancel()
    deviceStreamTask?.cancel()
  }

  func connectGlasses() {
    guard registrationState != .registering else { return }
    Task { @MainActor in
      do {
        try await wearables.startRegistration()
      } catch let error as RegistrationError {
        presentError(error.description)
      } catch {
        presentError(error.localizedDescription)
      }
    }
  }

  func disconnectGlasses() {
    Task { @MainActor in
      do {
        try await wearables.startUnregistration()
      } catch let error as UnregistrationError {
        presentError(error.description)
      } catch {
        presentError(error.localizedDescription)
      }
    }
  }

  func presentError(_ error: String) {
    errorMessage = error
    showError = true
  }

  func dismissError() {
    showError = false
  }
}
