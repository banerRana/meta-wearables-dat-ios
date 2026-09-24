/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import MWDATInputs
import Observation

enum InputControl: String, CaseIterable, Sendable {
  case up
  case down
  case left
  case right
  case select
  case back
  case capture
  case button
  case drag
}

@Observable
@MainActor
final class InputLogStore {
  struct Entry: Identifiable, Equatable {
    let id: UInt64
    let control: InputControl
    let label: String
    let detail: String
    let receivedAt: Date
  }

  private(set) var entries: [Entry] = []
  private(set) var flashedControl: InputControl?
  private(set) var flashToken: UInt64 = 0

  @ObservationIgnored private var nextId: UInt64 = 0
  @ObservationIgnored private static let maxEntries = 50

  nonisolated init() {}

  func record(_ event: InputEvent) {
    guard let described = Self.describe(event) else { return }
    nextId += 1
    let entry = Entry(
      id: nextId,
      control: described.control,
      label: described.label,
      detail: described.detail,
      receivedAt: Date()
    )
    entries = Array((entries + [entry]).suffix(Self.maxEntries))
    flashedControl = described.control
    flashToken &+= 1
  }

  func clear() {
    entries = []
    flashedControl = nil
  }

  private static func describe(_ event: InputEvent) -> (control: InputControl, label: String, detail: String)? {
    switch event {
    case let .nav(direction, source, _):
      let control: InputControl =
        switch direction {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
      return (control, "Nav \(direction)", "\(source)")
    case let .select(source, _):
      return (.select, "Select", "\(source)")
    case let .back(source, _):
      return (.back, "Back", "\(source)")
    case let .button(type, source, _):
      return (.button, "Button \(type)", "\(source)")
    case let .capture(pressType, source, _):
      return (.capture, "Capture \(pressType)", "\(source)")
    case let .drag(action, x, y, _, _, source, _):
      let label = "Drag \(action) (" + trim(x) + ", " + trim(y) + ")"
      return (.drag, label, "\(source)")
    @unknown default:
      return nil
    }
  }

  private static func trim(_ value: Float) -> String {
    "\(Float(Int(value * 100)) / 100)"
  }
}
