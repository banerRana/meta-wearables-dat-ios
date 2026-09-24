/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import MWDATCore
import MWDATInputs
import MWDATMotion
import MWDATSpeech
import Observation
import SwiftUI

enum SpeechStatus: Equatable {
  case idle
  case needsMicrophonePermission
  case requestingPermission
  case listening
  case microphoneDenied
  case unavailable
}

@Observable
@MainActor
final class PlaygroundViewModel {
  private(set) var hasActiveDevice: Bool = false
  private(set) var sessionState: DeviceSessionState = .idle
  /// The most recent motion sample (accelerometer/gyroscope/orientation). Drives the live numeric
  /// readout so motion is visible even when the device omits the fused `orientation` quaternion.
  private(set) var latestSample: MotionSample?
  private(set) var motionState: MotionState = .stopped
  private(set) var caption: String = ""
  private(set) var captionIsFinal: Bool = false
  private(set) var speechLocale: String?
  private(set) var speechStatus: SpeechStatus = .idle

  var showError: Bool = false
  var errorMessage: String = ""

  let inputLog: InputLogStore

  var isSessionActive: Bool { sessionState == .started }

  @ObservationIgnored private let wearables: WearablesInterface
  @ObservationIgnored private let deviceSelector: AutoDeviceSelector
  @ObservationIgnored private var session: DeviceSession?
  @ObservationIgnored private var motion: Motion?
  @ObservationIgnored private var inputs: Inputs?
  @ObservationIgnored private var speech: Speech?

  @ObservationIgnored private var deviceMonitorTask: Task<Void, Never>?
  @ObservationIgnored private var motionSamplesTask: Task<Void, Never>?
  @ObservationIgnored private var inputEventsTask: Task<Void, Never>?
  @ObservationIgnored private let tokenBag = ListenerTokenBag()
  @ObservationIgnored private var pendingErrorTask: Task<Void, Never>?

  init(wearables: WearablesInterface, inputLog: InputLogStore = InputLogStore()) {
    self.wearables = wearables
    self.deviceSelector = AutoDeviceSelector(wearables: wearables)
    self.inputLog = inputLog
  }

  isolated deinit {
    deviceMonitorTask?.cancel()
    motionSamplesTask?.cancel()
    inputEventsTask?.cancel()
    pendingErrorTask?.cancel()
    session?.stop()
  }

  // MARK: - Lifecycle

  func start() {
    guard deviceMonitorTask == nil else { return }
    deviceMonitorTask = Task { [weak self] in
      guard let self else { return }
      for await deviceId in self.deviceSelector.activeDeviceStream() {
        self.hasActiveDevice = deviceId != nil
        if deviceId != nil {
          self.startSessionIfNeeded()
        } else {
          self.teardownSession()
        }
      }
    }
  }

  func stop() {
    deviceMonitorTask?.cancel()
    deviceMonitorTask = nil
    pendingErrorTask?.cancel()
    pendingErrorTask = nil
    teardownSession()
  }

  // MARK: - Session

  private func startSessionIfNeeded() {
    guard session == nil else { return }
    do {
      let session = try wearables.createSession(deviceSelector: deviceSelector)
      self.session = session
      session.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.handleSessionStateChange(state) }
      }.store(in: tokenBag)
      session.errorPublisher.listen { [weak self] error in
        Task { @MainActor in self?.handleError(error) }
      }.store(in: tokenBag)
      sessionState = .starting
      try session.start()
    } catch {
      handleError(error)
      teardownSession()
    }
  }

  private func handleSessionStateChange(_ state: DeviceSessionState) {
    sessionState = state
    switch state {
    case .started:
      pendingErrorTask?.cancel()
      pendingErrorTask = nil
      showError = false
      activateCapabilities()
    case .stopped, .idle, .starting, .paused, .stopping:
      // Do not tear the session down from a transient session-state signal. Teardown is driven
      // solely by device removal via `activeDeviceStream`, matching the Android sample; reacting to
      // a momentary `.idle`/`.stopped` here would call `session.stop()` and kill a live session
      // (observed dropping the DWA transport mid-stream so continuous Motion sends hit a dead
      // channel).
      break
    }
  }

  private func activateCapabilities() {
    startMotion()
    startInputs()
    prepareSpeech()
  }

  // MARK: - Motion

  private func startMotion() {
    guard motion == nil, let session else { return }
    do {
      guard let motion = try session.addMotion(configuration: MotionConfiguration(samplingRate: .hz30)) else {
        return
      }
      self.motion = motion
      motion.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.motionState = state }
      }.store(in: tokenBag)
      let samples = motion.samples
      motionSamplesTask = Task { [weak self] in
        for await sample in samples {
          self?.latestSample = sample
        }
      }
      motion.start()
    } catch {
      handleError(error)
    }
  }

  // MARK: - Inputs

  private func startInputs() {
    guard inputs == nil, let session else { return }
    do {
      guard let inputs = try session.addInputs() else { return }
      self.inputs = inputs
      let events = inputs.events
      inputEventsTask = Task { [weak self] in
        for await event in events {
          self?.inputLog.record(event)
        }
      }
    } catch {
      handleError(error)
    }
  }

  // MARK: - Speech (microphone-gated)

  private func prepareSpeech() {
    guard speech == nil, speechStatus != .requestingPermission else { return }
    Task { [weak self] in
      guard let self else { return }
      do {
        let status = try await self.wearables.checkPermissionStatus(.microphone)
        if status == .granted {
          self.startSpeech()
        } else {
          self.speechStatus = .needsMicrophonePermission
        }
      } catch {
        self.speechStatus = .unavailable
        self.handleError(error)
      }
    }
  }

  func requestMicrophoneAndStartSpeech() {
    guard speechStatus == .needsMicrophonePermission || speechStatus == .microphoneDenied else { return }
    speechStatus = .requestingPermission
    Task { [weak self] in
      guard let self else { return }
      do {
        let status = try await self.wearables.requestPermission(.microphone)
        if status == .granted {
          self.startSpeech()
        } else {
          self.speechStatus = .microphoneDenied
        }
      } catch {
        self.speechStatus = .microphoneDenied
        self.handleError(error)
      }
    }
  }

  private func startSpeech() {
    guard speech == nil, let session else { return }
    do {
      guard let speech = try session.addSpeech() else { return }
      self.speech = speech
      speech.transcriptionPublisher.listen { [weak self] result in
        Task { @MainActor in
          self?.caption = result.text
          self?.captionIsFinal = result.isFinal
        }
      }.store(in: tokenBag)
      speech.localePublisher.listen { [weak self] locale in
        Task { @MainActor in self?.speechLocale = locale }
      }.store(in: tokenBag)
      speech.errorPublisher.listen { [weak self] error in
        Task { @MainActor in self?.handleError(error) }
      }.store(in: tokenBag)
      speech.start()
      speechStatus = .listening
    } catch {
      handleError(error)
    }
  }

  // MARK: - Teardown

  private func teardownSession() {
    motionSamplesTask?.cancel()
    motionSamplesTask = nil
    inputEventsTask?.cancel()
    inputEventsTask = nil
    tokenBag.clear()

    motion?.stop()
    motion = nil
    speech?.stop()
    speech = nil
    inputs = nil
    session?.stop()
    session = nil

    sessionState = .idle
    latestSample = nil
    motionState = .stopped
    caption = ""
    captionIsFinal = false
    speechLocale = nil
    speechStatus = .idle
  }

  // MARK: - Errors

  private func handleError(_ error: Error) {
    if let sessionError = error as? DeviceSessionError, sessionError.isTransientConnectionError {
      deferTransientConnectionError(error.localizedDescription)
    } else {
      presentError(error.localizedDescription)
    }
  }

  private func deferTransientConnectionError(_ message: String) {
    guard pendingErrorTask == nil else { return }
    pendingErrorTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard let self, !Task.isCancelled else { return }
      self.pendingErrorTask = nil
      guard self.sessionState != .started else { return }
      self.presentError(message)
    }
  }

  private func presentError(_ message: String) {
    errorMessage = message
    showError = true
  }

  func dismissError() {
    showError = false
  }
}

extension DeviceSessionError {
  /// Whether this error represents a transient connection-availability condition that can occur
  /// while the glasses connection is still being established, as opposed to a genuine failure.
  ///
  /// Callers can use this to defer surfacing an alert during connection bring-up and drop it if the
  /// session recovers, while still surfacing all other errors immediately.
  var isTransientConnectionError: Bool {
    switch self {
    case .noEligibleDevice, .dwaUnavailable:
      return true
    case .sessionAlreadyStopped,
      .sessionAlreadyExists,
      .sessionIdle,
      .capabilityAlreadyActive,
      .capabilityNotFound,
      .unexpectedError,
      .thermalCritical,
      .thermalEmergency,
      .peakPowerShutdown,
      .batteryCritical,
      .datAppOnTheGlassesUpdateRequired:
      return false
    @unknown default:
      return false
    }
  }
}
