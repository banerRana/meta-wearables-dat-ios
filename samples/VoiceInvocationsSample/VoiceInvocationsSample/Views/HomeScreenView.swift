/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel

  var body: some View {
    ZStack {
      Color.white.edgesIgnoringSafeArea(.all)

      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "waveform.circle.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 100)
          .foregroundStyle(.purple)

        Text("Voice Invocations Sample")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.black)

        VStack(alignment: .leading, spacing: 12) {
          HomeTipView(
            icon: "mic.fill",
            title: "Voice Commands",
            text: "Say \"Hey Meta, start {YOUR APP}\" to launch your app from your glasses."
          )
          HomeTipView(
            icon: "app.badge.fill",
            title: "Launch App",
            text: "Respond to launch app invocations from your wearable device."
          )
        }
        .padding(.horizontal, 8)

        Spacer()

        VStack(spacing: 16) {
          Text("You'll be redirected to the Meta AI app to confirm your connection.")
            .font(.system(size: 14))
            .foregroundStyle(.gray)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)

          Button {
            viewModel.connectGlasses()
          } label: {
            Text(viewModel.registrationState == .registering ? "Connecting..." : "Connect my glasses")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(viewModel.registrationState == .registering ? Color.gray : Color.purple)
              .cornerRadius(12)
          }
          .disabled(viewModel.registrationState == .registering)
        }
      }
      .padding(.all, 24)
    }
  }
}

struct HomeTipView: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 22)
        .foregroundStyle(.purple)
        .padding(.top, 4)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.black)

        Text(text)
          .font(.system(size: 14))
          .foregroundStyle(.gray)
      }
      Spacer()
    }
  }
}
