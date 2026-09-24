/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SwiftUI

struct InputHUDView: View {
  let store: InputLogStore

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        if store.entries.isEmpty {
          Text("Waiting for input")
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(AppColor.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityIdentifier("input_hud_latest")
        }

        ForEach(store.entries.reversed()) { entry in
          Text(rowText(entry))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(AppColor.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityIdentifier(entry.id == store.entries.last?.id ? "input_hud_latest" : "input_log_row")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(AppColor.surface.opacity(0.9))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func rowText(_ entry: InputLogStore.Entry) -> String {
    "\(entry.label.uppercased())  \u{00B7}  \(entry.detail)"
  }
}
