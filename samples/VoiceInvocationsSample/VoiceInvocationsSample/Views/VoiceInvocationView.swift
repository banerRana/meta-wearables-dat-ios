/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MWDATCore
import SwiftUI

#if DEBUG
import MWDATMockDevice
#endif

struct VoiceInvocationView: View {
  @ObservedObject var wearablesVM: WearablesViewModel
  @ObservedObject var voiceStore: VoiceInvocationsStore

  init(wearablesVM: WearablesViewModel, voiceStore: VoiceInvocationsStore) {
    self.wearablesVM = wearablesVM
    self.voiceStore = voiceStore
  }

  private var pendingCount: Int {
    voiceStore.queue.filter { $0.status == .pending }.count
  }

  private var isSessionActive: Bool {
    switch voiceStore.sessionPhase {
    case .idle, .stopped:
      return false
    case .waitingForDevice, .starting, .started, .stopping:
      return true
    }
  }

  #if DEBUG
  private var hasMockDevice: Bool {
    !MockDeviceKit.shared.pairedDevices.isEmpty
  }

  /// Triggers a mock LaunchApp from the paired mock glasses. The invocation flows back through the
  /// real stream owned by the store and is enqueued as pending, exercising the full SDK path.
  private func sendMockLaunchAppAction() {
    guard let device = MockDeviceKit.shared.pairedDevices.first as? MockGlasses else { return }
    _ = device.services.voiceInvocation.sendLaunchAppAction()
  }
  #endif

  var body: some View {
    VStack(spacing: 0) {
      headerSection

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          statusSection

          controlsSection

          #if DEBUG
          if hasMockDevice {
            mockActionsSection
          }
          #endif

          queuedInvocationsSection

          if !voiceStore.errorLog.isEmpty {
            errorLogSection
          }
        }
        .padding()
      }
    }
    .background(Color(.systemGroupedBackground))
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Voice Invocations")
          .font(.system(size: 22, weight: .bold))
        Text("\(wearablesVM.devices.count) device(s) connected")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        wearablesVM.disconnectGlasses()
      } label: {
        Text("Disconnect")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.red)
      }
    }
    .padding()
    .background(Color(.systemBackground))
  }

  // MARK: - Status

  private var statusSection: some View {
    HStack(spacing: 12) {
      Label {
        Text(sessionPhaseLabel)
          .font(.system(size: 14, weight: .medium))
      } icon: {
        Circle()
          .fill(sessionStateColor)
          .frame(width: 10, height: 10)
      }

      Spacer()

      Text("\(voiceStore.queue.count) event(s)")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
  }

  private var sessionPhaseLabel: String {
    switch voiceStore.sessionPhase {
    case .idle: return "IDLE"
    case .waitingForDevice: return "WAITING_FOR_DEVICE"
    case .starting: return "STARTING"
    case .started: return "STARTED"
    case .stopping: return "STOPPING"
    case .stopped: return "STOPPED"
    }
  }

  private var sessionStateColor: Color {
    switch voiceStore.sessionPhase {
    case .started: return .green
    case .starting, .stopping: return .yellow
    default: return .gray
    }
  }

  // MARK: - Controls

  private var controlsSection: some View {
    HStack(spacing: 12) {
      Button {
        voiceStore.start()
      } label: {
        Text("Start")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(isSessionActive ? Color.gray : Color.purple)
          .cornerRadius(10)
      }
      .disabled(isSessionActive)

      Button {
        voiceStore.stop()
      } label: {
        Text("Stop")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(isSessionActive ? Color.red : Color.gray)
          .cornerRadius(10)
      }
      .disabled(!isSessionActive)

      Button {
        voiceStore.clearLogs()
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
          .padding(12)
          .background(Color(.systemBackground))
          .cornerRadius(10)
      }
    }
  }

  // MARK: - Mock Actions

  #if DEBUG
  private var mockActionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Mock Device Actions")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        Button {
          sendMockLaunchAppAction()
        } label: {
          Text("LaunchApp")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
  }
  #endif

  // MARK: - Queued Invocations

  private var queuedInvocationsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Queued Invocations (\(pendingCount) pending)")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)

      if voiceStore.queue.isEmpty {
        Text("No invocations received yet. Start the stream and say \"Hey Meta\" to your glasses.")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(.systemBackground))
          .cornerRadius(12)
      } else {
        VStack(spacing: 8) {
          // Most-recent first.
          ForEach(voiceStore.queue.reversed()) { entry in
            QueuedInvocationCard(entry: entry) { success in
              voiceStore.acknowledge(entry, success: success)
            }
          }
        }
      }
    }
  }

  // MARK: - Error Log

  private var errorLogSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Errors")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.red)

      VStack(alignment: .leading, spacing: 4) {
        ForEach(voiceStore.errorLog, id: \.self) { error in
          Text(error)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.red)
        }
      }
      .padding()
      .background(Color(.systemBackground))
      .cornerRadius(12)
    }
  }
}

// MARK: - QueuedInvocationCard

private struct QueuedInvocationCard: View {
  let entry: QueuedInvocation
  let onAck: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Text(entry.type)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(entry.type == "LaunchApp" ? Color.blue : Color.orange)
          .frame(width: 90, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text(entry.detail)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
          Text(entry.receivedAt.formatted(date: .omitted, time: .standard))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        Spacer()

        Text(statusLabel)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(statusColor)
      }

      if entry.status == .pending {
        HStack(spacing: 8) {
          Button {
            onAck(true)
          } label: {
            Text("Ack Success")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(Color.green)
              .cornerRadius(8)
          }
          Button {
            onAck(false)
          } label: {
            Text("Ack Failure")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(Color.red)
              .cornerRadius(8)
          }
        }
      }
    }
    .padding(10)
    .background(Color(.systemBackground))
    .cornerRadius(12)
  }

  private var statusLabel: String {
    switch entry.status {
    case .pending: return "PENDING"
    case .ackedSuccess: return "ACKED ✓"
    case .ackedFailure: return "ACKED ✗"
    }
  }

  private var statusColor: Color {
    switch entry.status {
    case .pending: return .secondary
    case .ackedSuccess: return .green
    case .ackedFailure: return .red
    }
  }
}
