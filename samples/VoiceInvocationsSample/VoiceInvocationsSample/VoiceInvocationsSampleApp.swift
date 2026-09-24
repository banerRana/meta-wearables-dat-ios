/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import MWDATCore
import SwiftUI

#if DEBUG
import MWDATMockDevice
#endif

@main
struct VoiceInvocationsSampleApp: App {
  #if DEBUG
  @StateObject private var debugMenuViewModel = DebugMenuViewModel(mockDeviceKit: MockDeviceKit.shared)
  #endif
  private let wearables: WearablesInterface
  @StateObject private var wearablesViewModel: WearablesViewModel
  // Owned at app scope (not per-view) so a voice-triggered cold launch is captured before the UI
  // is ready. `start()` is idempotent, so re-invoking it later is a no-op.
  @StateObject private var voiceStore: VoiceInvocationsStore

  init() {
    do {
      try Wearables.configure()
    } catch {
      #if DEBUG
      NSLog("[VoiceInvocationsSample] Failed to configure Wearables SDK: \(error)")
      #endif
    }

    let wearables = Wearables.shared
    self.wearables = wearables
    self._wearablesViewModel = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
    self._voiceStore = StateObject(wrappedValue: VoiceInvocationsStore(wearables: wearables))
  }

  var body: some Scene {
    WindowGroup {
      MainAppView(wearables: wearables, viewModel: wearablesViewModel, voiceStore: voiceStore)
        .task {
          // Start the app-scoped stream as early as the UI mounts, ahead of any view's own
          // lifecycle, so an invocation from a cold launch is not dropped.
          voiceStore.start()
        }
        .alert("Error", isPresented: $wearablesViewModel.showError) {
          Button("OK") {
            wearablesViewModel.dismissError()
          }
        } message: {
          Text(wearablesViewModel.errorMessage)
        }
        #if DEBUG
      .sheet(isPresented: $debugMenuViewModel.showDebugMenu) {
        MockDeviceKitSheet(viewModel: debugMenuViewModel)
      }
      .overlay {
        DebugMenuView(debugMenuViewModel: debugMenuViewModel)
      }
        #endif

      RegistrationView(viewModel: wearablesViewModel)
    }
  }
}
