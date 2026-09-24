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
  let wearables: WearablesInterface
  @ObservedObject private var viewModel: WearablesViewModel
  @ObservedObject private var voiceStore: VoiceInvocationsStore

  init(
    wearables: WearablesInterface,
    viewModel: WearablesViewModel,
    voiceStore: VoiceInvocationsStore
  ) {
    self.wearables = wearables
    self.viewModel = viewModel
    self.voiceStore = voiceStore
  }

  var body: some View {
    if viewModel.registrationState == .registered {
      VoiceInvocationView(wearablesVM: viewModel, voiceStore: voiceStore)
    } else {
      HomeScreenView(viewModel: viewModel)
    }
  }
}
