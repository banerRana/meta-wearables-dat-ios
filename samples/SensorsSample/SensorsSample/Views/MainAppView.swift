/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATCore
import SwiftUI

struct MainAppView: View {
  let viewModel: WearablesViewModel
  let playground: PlaygroundViewModel

  var body: some View {
    PlaygroundScreen(wearables: viewModel, playground: playground)
  }
}

struct PlaygroundScreen: View {
  let wearables: WearablesViewModel
  let playground: PlaygroundViewModel

  var body: some View {
    ZStack {
      AppColor.background.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text("Sensors Playground")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppColor.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

          StatusRow(
            motionState: motionText,
            motionError: nil,
            inputsState: inputsText,
            inputsError: nil,
            speechState: speechText,
            speechError: speechError
          )

          ConnectionRow(
            registrationState: registrationText,
            sessionState: sessionText,
            canRegister: canRegister,
            onRegister: { wearables.connectGlasses() },
            canDisconnect: wearables.canDisconnect,
            onDisconnect: { wearables.disconnectGlasses() }
          )

          if playground.showError {
            ErrorBanner(message: playground.errorMessage) { playground.dismissError() }
          }

          ZStack {
            WireframeGlassesView(sample: playground.latestSample)
            InputFlashOverlay(
              control: playground.inputLog.flashedControl,
              token: playground.inputLog.flashToken
            )
          }
          .frame(maxWidth: .infinity)
          .frame(height: 300)
          .padding(.horizontal, 16)

          MotionReadout(sample: playground.latestSample)

          Text("Input log")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColor.onSurface)
            .padding(.horizontal, 16)

          InputHUDView(store: playground.inputLog)
            .frame(height: 140)
            .padding(.horizontal, 16)

          CaptionView(
            text: playground.caption,
            isFinal: playground.captionIsFinal,
            isMicActive: playground.speechStatus == .listening,
            locale: playground.speechLocale
          )
          .padding(.horizontal, 16)

          if showEnableMicrophone {
            EnableMicrophoneButton { playground.requestMicrophoneAndStartSpeech() }
              .padding(.horizontal, 16)
          }

          if !playground.hasActiveDevice {
            RealDeviceHint()
          }
        }
      }
    }
  }

  private var motionText: String {
    String(describing: playground.motionState).uppercased()
  }

  private var inputsText: String {
    switch playground.sessionState {
    case .starting:
      return "STARTING"
    case .started:
      return "STARTED"
    case .paused, .stopping:
      return "STOPPING"
    case .idle, .stopped:
      return "INACTIVE"
    @unknown default:
      return "INACTIVE"
    }
  }

  private var speechText: String {
    switch playground.speechStatus {
    case .idle, .needsMicrophonePermission, .microphoneDenied:
      return "STOPPED"
    case .requestingPermission:
      return "STARTING"
    case .listening:
      return "STARTED"
    case .unavailable:
      return "UNAVAILABLE"
    }
  }

  private var speechError: String? {
    switch playground.speechStatus {
    case .idle, .requestingPermission, .listening:
      return nil
    case .needsMicrophonePermission:
      return "Microphone permission needed"
    case .microphoneDenied:
      return "Microphone denied"
    case .unavailable:
      return "Unavailable"
    }
  }

  private var registrationText: String {
    wearables.registrationState.description.uppercased()
  }

  private var sessionText: String {
    switch playground.sessionState {
    case .idle:
      return "None"
    case .starting, .started, .paused, .stopping, .stopped:
      return String(describing: playground.sessionState).uppercased()
    @unknown default:
      return String(describing: playground.sessionState).uppercased()
    }
  }

  private var canRegister: Bool {
    wearables.canRegister
  }

  private var showEnableMicrophone: Bool {
    playground.speechStatus == .needsMicrophonePermission
      || playground.speechStatus == .microphoneDenied
  }
}

private struct EnableMicrophoneButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Enable microphone")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColor.accent)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("enable_microphone_button")
  }
}
