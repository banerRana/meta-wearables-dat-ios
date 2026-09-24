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
import os.log

#if DEBUG
import MWDATMockDevice
#endif

@main
struct SensorsSampleApp: App {
  private let wearables: WearablesInterface
  @State private var wearablesViewModel: WearablesViewModel
  @State private var playgroundViewModel: PlaygroundViewModel
  #if DEBUG
  @State private var debugMenuViewModel = DebugMenuViewModel(mockDeviceKit: MockDeviceKit.shared)
  #endif

  init() {
    do {
      try Wearables.configure()
    } catch {
      let logger = Logger(
        subsystem: "com.meta.wearables.external.SensorsSample",
        category: "SensorsSample"
      )
      logger.error("Failed to configure Wearables SDK: \(error.localizedDescription, privacy: .public)")
    }

    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
      MockDeviceKit.shared.enable()

      let portFilePath = ProcessInfo.processInfo.environment["MWDAT_TEST_SERVER_PORT_FILE"]
      Task {
        do {
          _ = try await MockDeviceKit.shared.startTestServer(portFilePath: portFilePath)
        } catch {
          let logger = Logger(
            subsystem: "com.meta.wearables.external.SensorsSample",
            category: "MockDeviceKit"
          )
          logger.error("Failed to start mock device test server: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
    #endif

    let wearables = Wearables.shared
    self.wearables = wearables
    self._wearablesViewModel = State(wrappedValue: WearablesViewModel(wearables: wearables))
    self._playgroundViewModel = State(wrappedValue: PlaygroundViewModel(wearables: wearables))
  }

  var body: some Scene {
    WindowGroup {
      MainAppView(viewModel: wearablesViewModel, playground: playgroundViewModel)
        .preferredColorScheme(.dark)
        .task {
          playgroundViewModel.start()
        }
        .alert("Error", isPresented: $wearablesViewModel.showError) {
          Button("OK") { wearablesViewModel.dismissError() }
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
        .onOpenURL { url in
          guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
          else {
            return
          }
          Task {
            do {
              _ = try await Wearables.shared.handleUrl(url)
            } catch let error as RegistrationError {
              wearablesViewModel.presentError(error.description)
            } catch {
              wearablesViewModel.presentError("Unknown error: \(error.localizedDescription)")
            }
          }
        }
    }
  }
}
