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
  @ObservedObject var viewModel: DebugMenuViewModel

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 8) {
            HStack {
              Text("Mock Device Kit")
                .font(.title2)
                .fontWeight(.bold)

              Spacer()

              Text("\(viewModel.pairedCount) device(s)")
                .font(.subheadline)
                .foregroundStyle(.green)
            }

            Text("Simulate wearable devices for testing voice invocations.")
              .font(.body)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if viewModel.isEnabled {
              Button(action: { viewModel.disable() }) {
                Text("Disable MockDeviceKit")
                  .fontWeight(.medium)
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.red)

              Button(action: { viewModel.pairGlasses() }) {
                Text("Pair Ray-Ban Meta")
                  .fontWeight(.medium)
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.purple)
              .disabled(viewModel.pairedCount >= 3)

              if viewModel.pairedCount > 0 {
                Button(action: { viewModel.unpairLastDevice() }) {
                  Text("Unpair Last Device")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
              }
            } else {
              Button(action: { viewModel.enable() }) {
                Text("Enable MockDeviceKit")
                  .fontWeight(.medium)
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.purple)
            }
          }
          .padding()
          .background(Color(.systemBackground))
          .cornerRadius(12)
          .shadow(color: .black.opacity(0.1), radius: 2)
        }
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Debug Menu")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#endif
