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

/// App-scoped owner of the ``VoiceInvocationsStream`` (the iOS analogue of the Android sample's
/// process-scoped `VoiceInvocationsRepository`).
///
/// The stream is owned here — created once at app scope and injected down — instead of by a
/// view-scoped view model, so a voice command that cold-launches the app is captured even before
/// the UI appears. The bounded ``queue`` of received invocations is the single source of truth:
/// because this is one long-lived `ObservableObject`, any view that appears later simply renders
/// the current queue, so nothing is missed or duplicated on view recreation.
///
/// Acknowledgment is user-driven: invocations arrive ``InvocationStatus/pending`` and are only
/// answered when the user taps Ack Success / Ack Failure. The per-invocation status is folded into
/// each ``QueuedInvocation`` so the view observes one stable list rather than a status flow per id.
@MainActor
final class VoiceInvocationsStore: ObservableObject {

  /// The bounded, ordered list of received invocations (oldest first), capped to the most recent
  /// ``maxQueue`` so a long-lived process cannot grow it without limit.
  @Published private(set) var queue: [QueuedInvocation] = []

  /// Type-safe session phase, replacing the previous stringly-typed session state.
  @Published private(set) var sessionPhase: VoiceSessionPhase = .idle

  /// Most-recent-first list of formatted error strings.
  @Published private(set) var errorLog: [String] = []

  /// Retained window of most-recent invocations. Matches the Android sample's `MAX_QUEUE`.
  private static let maxQueue = 64

  /// Maximum time to wait for a compatible device to connect before surfacing a timeout error.
  private static let deviceWaitTimeout: TimeInterval = 30

  private let wearables: WearablesInterface

  private var stream: VoiceInvocationsStream?
  private let tokenBag = ListenerTokenBag()
  private var deviceWaitTask: Task<Void, Never>?
  private var devicesStreamTask: Task<Void, Never>?
  private var startedDeviceIds: Set<DeviceIdentifier> = []
  private var observedDeviceIds: Set<DeviceIdentifier> = []
  private var nextId: UInt64 = 0

  init(wearables: WearablesInterface) {
    self.wearables = wearables
  }

  // MARK: - Lifecycle

  /// Starts the app-scoped stream. Idempotent: a second call while a stream is already running is a
  /// no-op (guards on an active stream, like the Android sample's `stream != null`), so calling this
  /// early at app launch and again from a view's `.onAppear` is safe.
  ///
  /// The stream and its listeners are wired up immediately — before any device is connected — so a
  /// cold-launch invocation is captured as soon as the per-device channel opens. Device selection
  /// and the per-device `start(deviceIdentifier:)` happen asynchronously via the observers below.
  func start() {
    guard stream == nil else { return }
    errorLog = []
    sessionPhase = .starting

    let newStream: VoiceInvocationsStream
    do {
      newStream = try VoiceInvocationsStream(wearables: wearables)
    } catch {
      handleError(error)
      sessionPhase = .stopped
      return
    }

    stream = newStream
    tokenBag.clear()

    newStream.invocationsPublisher.listen { [weak self] event in
      Task { @MainActor in
        self?.enqueue(event)
      }
    }.store(in: tokenBag)

    newStream.errorPublisher.listen { [weak self] error in
      Task { @MainActor in
        self?.handleError(error)
      }
    }.store(in: tokenBag)

    sessionPhase = .waitingForDevice
    beginDeviceObservation()
  }

  /// Stops the stream, cancels observers, and resets to ``VoiceSessionPhase/stopped``.
  func stop() {
    sessionPhase = .stopping
    deviceWaitTask?.cancel()
    deviceWaitTask = nil
    devicesStreamTask?.cancel()
    devicesStreamTask = nil
    stream?.stop()
    tokenBag.clear()
    stream = nil
    startedDeviceIds.removeAll()
    observedDeviceIds.removeAll()
    sessionPhase = .stopped
  }

  func clearLogs() {
    queue = []
    errorLog = []
  }

  // MARK: - Acknowledgment (user-driven)

  /// Acknowledges a queued invocation with success or failure.
  ///
  /// 1. Optimistically flips the entry ``InvocationStatus/pending`` → acked. The from-state guard is
  ///    the single-writer CAS equivalent: it guarantees exactly one send even on a double tap, and
  ///    ignores acks for already-acked or unknown-status entries.
  /// 2. Sends the SDK response; if the send fails, reverts the entry to ``InvocationStatus/pending``.
  ///
  /// Acks after ``stop()`` are ignored (no active stream).
  func acknowledge(_ entry: QueuedInvocation, success: Bool) {
    guard stream != nil, let handle = entry.responseHandle else { return }
    let target: InvocationStatus = success ? .ackedSuccess : .ackedFailure
    guard transitionStatus(id: entry.id, from: .pending, to: target) else { return }

    Task { [weak self] in
      let sent =
        success
        ? await handle.sendSuccess(actionOutput: nil)
        : await handle.sendFailure(actionOutput: nil)
      if !sent {
        self?.transitionStatus(id: entry.id, from: target, to: .pending)
      }
    }
  }

  // MARK: - Queue

  private func enqueue(_ event: any VoiceInvocation) {
    nextId += 1
    let entry = QueuedInvocation(
      id: nextId,
      receivedAt: Date(),
      type: displayType(for: event),
      detail: displayDetail(for: event),
      responseHandle: responseHandle(for: event)
    )
    queue = Array((queue + [entry]).suffix(Self.maxQueue))
  }

  /// Atomically transitions the status of the entry with `id` from `from` to `to`. Returns `true`
  /// only if the entry existed and was in the `from` state. `@MainActor` isolation serializes all
  /// callers, so this from-state check is the single-writer guard keeping the header count, card
  /// status, and send calls consistent.
  @discardableResult
  private func transitionStatus(id: UInt64, from: InvocationStatus, to: InvocationStatus) -> Bool {
    guard let index = queue.firstIndex(where: { $0.id == id }), queue[index].status == from else {
      return false
    }
    var updated = queue
    updated[index] = updated[index].withStatus(to)
    queue = updated
    return true
  }

  private func responseHandle(for event: any VoiceInvocation) -> ResponseHandle? {
    switch event {
    case let launchApp as LaunchApp:
      return launchApp.responseHandle
    default:
      return nil
    }
  }

  private func displayType(for event: any VoiceInvocation) -> String {
    switch event {
    case is LaunchApp:
      return "LaunchApp"
    default:
      return "Unknown"
    }
  }

  private func displayDetail(for event: any VoiceInvocation) -> String {
    switch event {
    case let launchApp as LaunchApp:
      return "device: \(launchApp.deviceIdentifier)"
    default:
      return "\(Swift.type(of: event))"
    }
  }

  private func handleError(_ error: Error) {
    let timestamp = Date().formatted(date: .omitted, time: .standard)
    errorLog.insert("[\(timestamp)] \(error.localizedDescription)", at: 0)
  }

  // MARK: - Device lifecycle
  //
  // Relocated from the former view model so device selection and per-device `start` are owned by the
  // app-scoped store. Behavior is unchanged; only ownership moved and the stream is now created
  // up front in `start()` rather than after the device wait.

  private func beginDeviceObservation() {
    observeDevices(wearables.devices)

    devicesStreamTask = Task { [weak self] in
      guard let self else { return }
      for await deviceIds in self.wearables.devicesStream() {
        self.observeDevices(deviceIds)
      }
    }

    // Surface a clear timeout if no compatible device connects, instead of leaving the UI waiting
    // forever. The reactive observers above handle the happy path; this only reports the failure.
    let selector = AutoDeviceSelector(wearables: wearables)
    deviceWaitTask = Task { [weak self] in
      let deviceAvailable = await Self.waitForActiveDevice(
        selector: selector,
        timeout: Self.deviceWaitTimeout
      )
      guard let self, self.stream != nil else { return }
      self.deviceWaitTask = nil
      if !deviceAvailable && self.startedDeviceIds.isEmpty {
        self.handleError(VoiceInvocationError.deviceNotFound)
        self.stop()
      }
    }
  }

  /// Suspends until the selector reports an active (connected + compatible) device, or the timeout
  /// elapses. `activeDevice` resolves immediately when a device is already connected.
  private static func waitForActiveDevice(
    selector: AutoDeviceSelector,
    timeout: TimeInterval
  ) async -> Bool {
    if selector.activeDevice != nil { return true }
    return await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        for await device in selector.activeDeviceStream() where device != nil {
          return true
        }
        return false
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        return false
      }
      let available = await group.next() ?? false
      group.cancelAll()
      return available
    }
  }

  private func observeDevices(_ deviceIds: [DeviceIdentifier]) {
    for deviceId in deviceIds {
      guard let device = wearables.deviceForIdentifier(deviceId) else { continue }
      if device.linkState == .connected {
        startSessionForDevice(deviceId)
      }
      guard observedDeviceIds.insert(deviceId).inserted else { continue }
      device.addLinkStateListener { [weak self] state in
        Task { @MainActor [weak self] in
          self?.handleLinkStateChange(deviceId: deviceId, state: state)
        }
      }.store(in: tokenBag)
    }
  }

  private func handleLinkStateChange(deviceId: DeviceIdentifier, state: LinkState) {
    guard stream != nil else { return }
    if state == .connected {
      startSessionForDevice(deviceId)
    } else {
      // Drop the device so a later reconnect re-starts its per-device stream, and fall back to
      // waitingForDevice once nothing is connected anymore.
      startedDeviceIds.remove(deviceId)
      if startedDeviceIds.isEmpty {
        sessionPhase = .waitingForDevice
      }
    }
  }

  private func startSessionForDevice(_ deviceId: DeviceIdentifier) {
    guard let stream,
      startedDeviceIds.insert(deviceId).inserted
    else { return }
    do {
      try stream.start(deviceIdentifier: deviceId)
      sessionPhase = .started
    } catch {
      startedDeviceIds.remove(deviceId)
      handleError(error)
    }
  }
}
