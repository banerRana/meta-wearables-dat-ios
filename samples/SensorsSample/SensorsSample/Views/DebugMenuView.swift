/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if DEBUG

import SwiftUI

struct DebugMenuView: View {
  @Bindable var debugMenuViewModel: DebugMenuViewModel

  var body: some View {
    HStack {
      Spacer()
      VStack {
        Spacer()
        Button(action: {
          debugMenuViewModel.openFromFab()
        }) {
          Image(systemName: "ant.fill")
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(AppColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 4)
        }.accessibilityIdentifier("debug_menu_button")
        Spacer()
      }
      .padding(.trailing)
    }
  }
}

#endif
