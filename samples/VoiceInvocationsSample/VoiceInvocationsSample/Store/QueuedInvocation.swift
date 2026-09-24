/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import MWDATCore

/// Acknowledgment status of a single queued invocation.
///
/// Every invocation arrives ``pending`` and stays pending until the user acknowledges it, mirroring
/// the Android sample. It never auto-acks at the listener boundary.
enum InvocationStatus: Sendable, Equatable {
  case pending
  case ackedSuccess
  case ackedFailure
}

/// A single voice invocation buffered by ``VoiceInvocationsStore``.
///
/// The queue of these is the single source of truth for the UI: it carries the display fields plus
/// the per-invocation acknowledgment ``status`` so the view renders one stable, observable list
/// rather than a separate log and status map. `status` is updated by immutable copy
/// (``withStatus(_:)``), exactly like the Android sample's `QueuedInvocation.copy(status = …)`.
struct QueuedInvocation: Identifiable, Sendable {
  /// Monotonically increasing id assigned by the store on receipt. Stable across status changes.
  let id: UInt64
  let receivedAt: Date
  /// Short type label for display.
  let type: String
  /// Human-readable device detail for display.
  let detail: String
  let status: InvocationStatus

  /// The SDK handle used to acknowledge this invocation. `nil` for unknown invocation types that
  /// cannot be acknowledged. Kept internal — only the store uses it.
  let responseHandle: ResponseHandle?

  init(
    id: UInt64,
    receivedAt: Date,
    type: String,
    detail: String,
    status: InvocationStatus = .pending,
    responseHandle: ResponseHandle?
  ) {
    self.id = id
    self.receivedAt = receivedAt
    self.type = type
    self.detail = detail
    self.status = status
    self.responseHandle = responseHandle
  }

  /// Returns a copy with a new ``status``, preserving all other fields (including the handle).
  func withStatus(_ status: InvocationStatus) -> QueuedInvocation {
    QueuedInvocation(
      id: id,
      receivedAt: receivedAt,
      type: type,
      detail: detail,
      status: status,
      responseHandle: responseHandle
    )
  }
}

/// The lifecycle phase of the app-scoped voice invocations session.
///
/// iOS has no SDK-provided voice session state (unlike Android's `SessionState`), so the sample
/// models its own type-safe phase instead of the previous stringly-typed value.
enum VoiceSessionPhase: Sendable, Equatable {
  case idle
  case waitingForDevice
  case starting
  case started
  case stopping
  case stopped
}
