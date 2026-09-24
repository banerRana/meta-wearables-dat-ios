/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SwiftUI

struct CaptionView: View {
  let text: String
  let isFinal: Bool
  let isMicActive: Bool
  let locale: String?

  @State private var pulse: Double = 0.35

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Circle()
          .fill(isMicActive ? AppColor.speech : AppColor.onSurfaceMuted)
          .frame(width: 10, height: 10)
          .opacity(isMicActive ? pulse : 0.25)
        Text("Speech")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AppColor.onSurface)
        if hasCaption {
          Text(isFinal ? "final" : "partial")
            .font(.system(size: 11))
            .foregroundStyle(isFinal ? AppColor.positive : AppColor.warning)
        }
        if let locale {
          Text(locale)
            .font(.system(size: 11))
            .foregroundStyle(AppColor.onSurfaceMuted)
        }
        Spacer(minLength: 0)
      }

      Text(hasCaption ? text : "Say something...")
        .font(.system(size: 16))
        .foregroundStyle(hasCaption ? AppColor.onSurface : AppColor.onSurfaceMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("caption_text")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .onAppear {
      withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
        pulse = 1.0
      }
    }
  }

  private var hasCaption: Bool { !text.isEmpty }
}
